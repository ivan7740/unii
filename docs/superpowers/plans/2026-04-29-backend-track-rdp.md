# Backend Track RDP Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `GET /api/locations/track/:user_id` 接口加入可选的服务端 Ramer-Douglas-Peucker 简化，通过 `epsilon_meters` 参数按需压缩返回点数，降低网络传输量。

**Architecture:** 新建 `src/utils/rdp.rs` 实现纯算法（迭代版，返回保留下标）；`TrackQuery` 新增可选字段 `epsilon_meters`；`service::get_user_track` 在获取原始点后，若参数存在则调用 RDP 并仅返回简化点集。响应类型不变（`Vec<TrackPoint>`），向后兼容。

**Tech Stack:** Rust, Axum 0.8, sqlx, chrono

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `unii-server/src/utils/rdp.rs` | 纯 RDP 算法 + 单元测试 |
| 修改 | `unii-server/src/utils/mod.rs` | 新增 `pub mod rdp;` |
| 修改 | `unii-server/src/models/location.rs` | `TrackPoint` 加 `Clone`；`TrackQuery` 加 `epsilon_meters` |
| 修改 | `unii-server/src/location/service.rs` | 获取原始点后按需调用 RDP |
| 修改 | `todolist.md` | 标记 Phase 7 `[B]` 项完成 |

---

### Task 1: RDP 算法模块（TDD）

**Files:**
- Create: `unii-server/src/utils/rdp.rs`
- Modify: `unii-server/src/utils/mod.rs`

- [ ] **Step 1: 注册模块**

编辑 `unii-server/src/utils/mod.rs`，内容替换为：

```rust
pub mod mask;
pub mod rdp;
```

- [ ] **Step 2: 创建含失败测试的 rdp.rs**

新建 `unii-server/src/utils/rdp.rs`，先只写测试（函数暂不存在）：

```rust
/// Ramer-Douglas-Peucker 轨迹简化。
///
/// 参数：
///   points  — (latitude, longitude) 切片
///   epsilon_meters — 简化容差（米）
///
/// 返回保留点的原始下标列表（已包含首尾），升序排列。
/// 点数 < 3 时直接返回全部下标。
pub fn simplify(points: &[(f64, f64)], epsilon_meters: f64) -> Vec<usize> {
    todo!()
}

fn perpendicular_dist(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fewer_than_3_points_returned_as_is() {
        let points = vec![(39.0, 116.0), (39.1, 116.1)];
        assert_eq!(simplify(&points, 15.0), vec![0, 1]);
    }

    #[test]
    fn test_collinear_200_simplified_to_endpoints() {
        // 200 点沿经度轴均匀分布（共线），应只保留首尾
        let points: Vec<(f64, f64)> = (0..200)
            .map(|i| (39.0, 116.0 + i as f64 * 0.0001))
            .collect();
        let result = simplify(&points, 15.0);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0], 0);
        assert_eq!(result[1], 199);
    }

    #[test]
    fn test_significant_bend_preserved() {
        // L 形轨迹：先向东 100 点，再向北 100 点（折弯应被保留）
        let mut points: Vec<(f64, f64)> = (0..100)
            .map(|i| (39.0, 116.0 + i as f64 * 0.001))
            .collect();
        points.extend((0..100).map(|i| (39.0 + (i + 1) as f64 * 0.001, 116.099)));
        let result = simplify(&points, 5.0);
        assert!(result.len() > 2, "bend should be preserved, got {} points", result.len());
        assert_eq!(result[0], 0);
        assert_eq!(*result.last().unwrap(), 199);
    }

    #[test]
    fn test_lower_precision_returns_fewer_or_equal_points() {
        // 正弦波形路径（有规律弯折）
        let points: Vec<(f64, f64)> = (0..200)
            .map(|i| (39.0 + (i % 10) as f64 * 0.0001, 116.0 + i as f64 * 0.001))
            .collect();
        let high = simplify(&points, 5.0);
        let low = simplify(&points, 50.0);
        assert!(
            low.len() <= high.len(),
            "low precision should keep ≤ points: low={} high={}",
            low.len(),
            high.len()
        );
    }
}
```

- [ ] **Step 3: 运行测试确认编译失败（todo! 会 panic）**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test utils::rdp 2>&1 | head -20
```

期望：编译通过但测试 panic（`todo!`），或直接看到 4 个测试被触发。

- [ ] **Step 4: 实现 `perpendicular_dist` 和 `simplify`**

将 `rdp.rs` 的两个函数替换为完整实现（保留测试不变）：

```rust
/// Ramer-Douglas-Peucker 轨迹简化（迭代版，避免递归栈溢出）。
///
/// points  — (latitude, longitude) 切片
/// epsilon_meters — 简化容差（米）
///
/// 返回保留点的原始下标列表，升序排列，始终包含首尾。
/// 点数 < 3 时直接返回全部下标（不简化）。
pub fn simplify(points: &[(f64, f64)], epsilon_meters: f64) -> Vec<usize> {
    let n = points.len();
    if n < 3 {
        return (0..n).collect();
    }

    // 1° ≈ 111 000 m；将米转为度数（欧氏近似，户外尺度足够精度）
    let epsilon_deg = epsilon_meters / 111_000.0;

    let mut keep = vec![false; n];
    keep[0] = true;
    keep[n - 1] = true;

    // 显式栈替代递归：每项为 (start_idx, end_idx)
    let mut stack: Vec<(usize, usize)> = vec![(0, n - 1)];

    while let Some((start, end)) = stack.pop() {
        let mut max_dist = 0.0_f64;
        let mut max_idx = start;

        for i in (start + 1)..end {
            let d = perpendicular_dist(points[i], points[start], points[end]);
            if d > max_dist {
                max_dist = d;
                max_idx = i;
            }
        }

        if max_dist > epsilon_deg {
            keep[max_idx] = true;
            stack.push((start, max_idx));
            stack.push((max_idx, end));
        }
    }

    (0..n).filter(|&i| keep[i]).collect()
}

/// 点 p 到线段 (a, b) 的垂直距离（度数单位，与 epsilon_deg 量纲一致）。
fn perpendicular_dist(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    let dx = b.1 - a.1; // longitude diff
    let dy = b.0 - a.0; // latitude diff
    let len_sq = dx * dx + dy * dy;

    if len_sq == 0.0 {
        // 线段退化为点
        let ex = p.1 - a.1;
        let ey = p.0 - a.0;
        return (ex * ex + ey * ey).sqrt();
    }

    let t = ((p.1 - a.1) * dx + (p.0 - a.0) * dy) / len_sq;
    let t_c = t.clamp(0.0, 1.0);
    let proj_lng = a.1 + t_c * dx;
    let proj_lat = a.0 + t_c * dy;
    let ex = p.1 - proj_lng;
    let ey = p.0 - proj_lat;
    (ex * ex + ey * ey).sqrt()
}
```

- [ ] **Step 5: 运行测试确认全部通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test utils::rdp 2>&1
```

期望：

```
test utils::rdp::tests::test_collinear_200_simplified_to_endpoints ... ok
test utils::rdp::tests::test_fewer_than_3_points_returned_as_is ... ok
test utils::rdp::tests::test_lower_precision_returns_fewer_or_equal_points ... ok
test utils::rdp::tests::test_significant_bend_preserved ... ok

test result: ok. 4 passed; 0 failed
```

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && \
  git add unii-server/src/utils/rdp.rs unii-server/src/utils/mod.rs && \
  git commit -m "feat(track): add iterative RDP simplification algorithm with unit tests"
```

---

### Task 2: 更新数据模型

**Files:**
- Modify: `unii-server/src/models/location.rs`

- [ ] **Step 1: 添加 `Clone` 到 `TrackPoint`，`epsilon_meters` 到 `TrackQuery`**

打开 `unii-server/src/models/location.rs`，做以下两处修改：

**修改 1**：`TrackPoint` derive 行（第 50 行）：

旧：
```rust
#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct TrackPoint {
```

新：
```rust
#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct TrackPoint {
```

**修改 2**：`TrackQuery` 结构体（第 59-65 行），新增 `epsilon_meters` 字段：

旧：
```rust
#[derive(Debug, Deserialize)]
pub struct TrackQuery {
    pub team_id: Uuid,
    pub start: Option<DateTime<Utc>>,
    pub end: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
}
```

新：
```rust
#[derive(Debug, Deserialize)]
pub struct TrackQuery {
    pub team_id: Uuid,
    pub start: Option<DateTime<Utc>>,
    pub end: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    /// 服务端 RDP 简化容差（米）。不传则返回原始点集。
    pub epsilon_meters: Option<f64>,
}
```

- [ ] **Step 2: 确认编译通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1 | grep -E "error|warning" | head -20
```

期望：无 error，warning 数量不增加。

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && \
  git add unii-server/src/models/location.rs && \
  git commit -m "feat(track): add Clone to TrackPoint, epsilon_meters to TrackQuery"
```

---

### Task 3: 在 service.rs 应用 RDP

**Files:**
- Modify: `unii-server/src/location/service.rs`

- [ ] **Step 1: 在文件顶部添加 rdp 导入**

打开 `unii-server/src/location/service.rs`，在已有 `use` 块后追加一行：

```rust
use crate::utils::rdp;
```

最终 use 块看起来像：

```rust
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{AppError, AppResult};
use crate::models::location::{
    MemberLocation, ReportLocationRequest, ReportLocationResponse, TrackPoint, TrackQuery,
};
use crate::utils::rdp;
```

- [ ] **Step 2: 在 `get_user_track` 末尾应用简化**

找到 `get_user_track` 函数（目前 `Ok(track)` 是最后一行，约 146-148 行），将整个返回部分替换为：

旧：
```rust
    Ok(track)
}
```

新：
```rust
    if let Some(eps) = query.epsilon_meters {
        let points: Vec<(f64, f64)> = track.iter().map(|p| (p.latitude, p.longitude)).collect();
        let keep = rdp::simplify(&points, eps.max(0.1));
        let simplified = keep.into_iter().map(|i| track[i].clone()).collect();
        Ok(simplified)
    } else {
        Ok(track)
    }
}
```

- [ ] **Step 3: 运行全部测试确认无回归**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1 | tail -10
```

期望：所有已有测试继续通过，无新增 error。

- [ ] **Step 4: Clippy 检查**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo clippy 2>&1 | grep "^error" | head -10
```

期望：无 error 输出。

- [ ] **Step 5: 手动验证（可选，需数据库）**

若本地有数据库运行，可用 curl 验证：

```bash
# 先获取 token（替换为实际值）
TOKEN="<your_jwt>"
USER_ID="<target_user_uuid>"
TEAM_ID="<team_uuid>"

# 原始点数
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/locations/track/$USER_ID?team_id=$TEAM_ID" \
  | jq 'length'

# 简化后点数（应显著减少）
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/locations/track/$USER_ID?team_id=$TEAM_ID&epsilon_meters=15" \
  | jq 'length'
```

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && \
  git add unii-server/src/location/service.rs && \
  git commit -m "feat(track): apply server-side RDP simplification when epsilon_meters provided"
```

---

### Task 4: 更新 todolist.md

**Files:**
- Modify: `todolist.md`

- [ ] **Step 1: 将未完成项标记为完成**

打开 `todolist.md`，将第 182 行：

```
- [ ] **[B]** 优化轨迹查询：时间范围筛选、Douglas-Peucker 轨迹简化
```

改为：

```
- [x] **[B]** 优化轨迹查询：时间范围筛选（start/end 已有）、服务端 Douglas-Peucker 简化（epsilon_meters 可选参数）
```

- [ ] **Step 2: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && \
  git add todolist.md && \
  git commit -m "chore: mark Phase 7 backend track RDP as done"
```
