import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn build_path(base: String, segments: List(String)) -> String {
  segments
  |> list.fold(base, fn(path, segment) { path <> "/" <> segment })
}

/// Set the JSON content type header and JSON body if json_body is not None
pub fn set_json(req: request.Request(String), json_body: Option(String)) {
  case json_body {
    Some(body) ->
      req
      |> request.set_header("Content-Type", "application/json")
      |> request.set_body(body)

    None -> req
  }
}
