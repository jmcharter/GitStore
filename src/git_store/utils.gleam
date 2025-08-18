import gleam/list

pub fn build_path(base: String, segments: List(String)) -> String {
  segments
  |> list.fold(base, fn(path, segment) { path <> "/" <> segment })
}
