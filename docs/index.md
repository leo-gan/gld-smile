# mojo-smile

mojo-smile is a [Smile](https://github.com/FasterXML/smile-format-specification)
serializer written in [Mojo](https://www.modular.com/mojo). The runtime and the
code generator are Mojo. They do not wrap Jackson, libsmile, or any other C,
C++, or Rust Smile library.

<div class="grid cards" markdown="1">

-   __Why Smile__

    ---

    What a Smile value is, which number classes stay distinct, and how shared
    names differ from shared values.

    [:octicons-arrow-right-24: Read Why Smile](why-smile.md)

-   __Instructions__

    ---

    Install Mojo 1.1.0 with pixi, decode a buffer, generate Mojo from a schema,
    and run the tests.

    [:octicons-arrow-right-24: Open Instructions](instructions.md)

-   __Examples__

    ---

    Encode and decode a dynamic document and a generated struct.

    [:octicons-arrow-right-24: See Examples](examples.md)

-   __Techniques__

    ---

    How the document arena, 7-bit payloads, and share windows are laid out.

    [:octicons-arrow-right-24: Read Techniques](techniques.md)

-   __Test data__

    ---

    The Jackson byte vectors and the local schema files.

    [:octicons-arrow-right-24: Open Test data](test-data.md)

</div>
