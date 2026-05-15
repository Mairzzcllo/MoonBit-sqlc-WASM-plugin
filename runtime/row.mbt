///|
/// Row abstraction for reading query results.
/// Provides indexed access to column values.

/// Concrete Row handle wrapping a row of results.
pub struct Row {
  get_fn : (Int) -> String
}

pub fn Row::new(get_fn: (Int) -> String) -> Row {
  { get_fn: get_fn }
}

pub fn Row::get(self: Row, index: Int) -> String {
  (self.get_fn)(index)
}
