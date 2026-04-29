# 后端轨迹 RDP 简化设计规格

**目标：** 在 unii-server 轨迹查询接口中加入服务端 Ramer-Douglas-Peucker 简化，通过可选 `epsilon_meters` 参数按需压缩返回点数，降低网络传输量。

---

## 现状

`GET /api/locations/track/:user_id` 已支持 `start`/`end` 时间过滤，但始终返回原始点集（最多 `limit`=5000 点）。前端 `TrackUtils.simplify()` 在本地做 D-P，但不能减少网络流量。

---

## 架构

### 文件变更

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `src/utils/rdp.rs` | 纯 RDP 算法（迭代版），含单元测试 |
| 修改 | `src/utils/mod.rs` | `pub mod rdp;` |
| 修改 | `src/models/location.rs` | `TrackQuery` 新增 `epsilon_meters: Option<f64>` |
| 修改 | `src/location/service.rs` | 获取原始点后按需调用 `rdp::simplify` |

### API 变更（向后兼容）

```
GET /api/locations/track/:user_id
    ?team_id=<uuid>
    &start=<iso8601>          # 已有
    &end=<iso8601>            # 已有
    &limit=<i64>              # 已有
    &epsilon_meters=<f64>     # 新增（可选）
```

- **不传 `epsilon_meters`**：与现有行为完全相同，返回原始点集
- **传入（如 `epsilon_meters=15.0`）**：服务端做 D-P 简化，响应类型仍为 `Vec<TrackPoint>`

---

## RDP 算法（`src/utils/rdp.rs`）

### 函数签名

```rust
/// 返回 indices（原始数组下标），调用方通过 index 重建结果。
pub fn simplify_indices(points: &[(f64, f64)], epsilon_deg: f64) -> Vec<usize>;

/// 便捷包装：直接接受 epsilon_meters，返回保留的下标。
pub fn simplify_track(point_count: usize, get_point: impl Fn(usize) -> (f64, f64), epsilon_meters: f64) -> Vec<usize>;
```

实际向 service 暴露的接口：

```rust
/// 给定 lat/lng 切片，返回保留点的下标列表（已含首尾）。
pub fn simplify(latitudes: &[f64], longitudes: &[f64], epsilon_meters: f64) -> Vec<usize>
```

### 关键参数

- `epsilon_deg = epsilon_meters / 111_000.0`（经纬度欧氏近似，1°≈111 km，户外精度足够）
- 点数 < 10 时跳过，直接返回 `0..n` 全部下标
- **迭代版**（使用显式栈 `Vec<(usize, usize)>`），避免递归栈溢出

### 垂直距离计算

点 P 到线段 (A, B) 的垂直距离（度数单位）：

```
d = ||(P - A) × (B - A)|| / ||B - A||
```

若线段退化为点（A == B），返回 ||P - A||。

---

## service.rs 变更

```rust
// 获取原始点后
let track = sqlx::query_as::<_, TrackPoint>(...).fetch_all(db).await?;

if let Some(eps) = query.epsilon_meters {
    let lats: Vec<f64> = track.iter().map(|p| p.latitude).collect();
    let lngs: Vec<f64> = track.iter().map(|p| p.longitude).collect();
    let keep = rdp::simplify(&lats, &lngs, eps.max(0.1));
    Ok(keep.into_iter().map(|i| track[i].clone()).collect())
} else {
    Ok(track)
}
```

---

## 单元测试（rdp.rs 内部）

| 测试 | 期望 |
|------|------|
| 点数 < 10 | 返回全部下标 |
| 共线 200 点 | 保留首尾 2 点 |
| L 型折弯 200 点 | 保留 > 2 点（折弯被保留） |
| 低精度保留点 ≤ 高精度保留点 | `eps=50m` 点数 ≤ `eps=5m` 点数 |

---

## 完成标准

1. `cargo test utils::rdp` 全部通过
2. `GET /api/locations/track/:uid?epsilon_meters=15.0` 返回点数显著少于不带参数的版本
3. 不传 `epsilon_meters` 时行为与修改前完全一致
4. `cargo clippy` 无 warning
5. 更新 `todolist.md` 标记 `[B]` 项为完成
