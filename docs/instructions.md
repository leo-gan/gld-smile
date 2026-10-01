# Instructions

The package needs Mojo 1.1.0 on linux-64. Pixi installs that compiler from the
Modular channel and conda-forge.

## Install the published package

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-smile
```

The conda package name is `mojo-smile`. The Mojo import is `smile`. The
generator binary is `gld-smilegen-mojo`.

## Build this repository

```bash
git clone https://github.com/leo-gan/gld-smile.git
cd gld-smile
pixi install
pixi run test
```

If `pixi install` returns 401 from `conda.modular.com`, put `PREFIX_API_KEY` in
a file named `.env` in the repository root and run `scripts/ci-setup.sh`. That
file is gitignored. Do not commit it.

## Generate structs

JSON Schema files live in `testdata/schema/`. The generator reads one file and
writes one Mojo file per object or union.

```bash
pixi run mojo run -I src src/codegen/cli.mojo -- \
  --schema testdata/schema/point.json \
  --out tests/generated
```

`pixi run generate` regenerates every schema. `pixi run check-generated`
regenerates into a temporary directory and diffs it against `tests/generated`.

A generated struct has `encoded_len`, `encode_to`, and `decode_from`. Integer
fields are `Int64`. Number fields are `Float64`. `binary` is `List[Byte]`.
`biginteger` and `bigdecimal` are decimal text, and the decimal text keeps
scale (`1.00` is not `1`).

The generator accepts the same JSON Schema subset as the other gld JSON
libraries: `type`, `properties`, `required`, `items`, `$ref`, `$defs`,
`definitions`, `enum`, `const`, `oneOf`, and `anyOf`. Smile adds the type
names `binary`, `biginteger`, and `bigdecimal`. A schema that refers to itself
is rejected, because Mojo does not allow that struct shape.
