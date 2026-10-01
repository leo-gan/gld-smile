# mojo-smile

A from-scratch [Smile](https://github.com/FasterXML/smile-format-specification) implementation for
[Mojo](https://mojolang.org/). The runtime and the code generator are written
in Mojo. They do not wrap, link, or vendor Jackson, libsmile, or any other C,
C++, or Rust Smile library.

Jackson `jackson-dataformat-smile` 2.13.5 is a **test oracle** for golden byte
vectors. It is not required to encode or decode at runtime.

This repository is a standalone library. It is not part of any other project.

Documentation: [leo-gan.github.io/gld-smile](https://leo-gan.github.io/gld-smile/).
That site has a Smile format overview for new readers, the install steps, JSON
Schema walkthrough, examples, encode/decode techniques, and test-data notes.

## Install

Published package (linux-64) on [prefix.dev/leo-gan/leo-gan](https://prefix.dev/leo-gan/leo-gan):

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-smile
```

## Develop

```bash
git clone https://github.com/leo-gan/gld-smile.git
cd gld-smile
pixi install
pixi run test
```

If `pixi install` fails with 401 on `conda.modular.com`, set `PREFIX_API_KEY`
in a local `.env` (never commit that file) and run `scripts/ci-setup.sh`.

## License

MIT. Copyright (c) 2026 Leonid Ganeline.
