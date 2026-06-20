# Golden test fixtures

Codegen golden tests live inline in `plugin/golden.mbt` as the `GOLDEN_USERS` constant and related `test "golden: ..."` blocks.

There is no external JSON fixture for the users scenario — run `moon test` in the plugin package to validate codegen output.

To refresh integration compilation fixtures after schema or codegen changes:

1. `moon build --target wasm`
2. `cd examples/users && sqlc generate`
3. Update `tests/integration/basic/generated.mbt` and `tests/integration/wasm/generated.mbt` stubs to mirror the generated types and query shapes.
