/// Minimal generated types fixture — uses the published runtime package.

pub struct User {
  id: Int64
  name: String
  email: String
  created_at: @rt.DateTime
}

pub fn User::decode(row: @rt.Row) -> Result[User, @rt.DBError] {
  match row.index_of("id") {
    Ok(_idx_0) => match row.get_int64(_idx_0) {
      Ok(id) => match row.index_of("name") {
        Ok(_idx_1) => match row.get_string(_idx_1) {
          Ok(name) => match row.index_of("email") {
            Ok(_idx_2) => match row.get_string(_idx_2) {
              Ok(email) => match row.index_of("created_at") {
                Ok(_idx_3) => match row.get_datetime(_idx_3) {
                  Ok(created_at) => Ok({ id: id, name: name, email: email, created_at: created_at })
                  Err(e) => Err(e)
                }
                Err(e) => Err(e)
              }
              Err(e) => Err(e)
            }
            Err(e) => Err(e)
          }
          Err(e) => Err(e)
        }
        Err(e) => Err(e)
      }
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}
