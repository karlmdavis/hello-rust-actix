# "Hello World!" via Rust and Actix

This Glitch project is a proof of concept for using Glitch with Rust, and specifically using Rust's [Actix](https://actix.rs/) web framework to run a simple "Hello World!" backend web application.

At the moment, the project's compiled nature isn't a great fit for Glitch: launching from a cold start hilariously takes about TODO minutes to compile and kick things off. But once it's running, everything's peachy!

## Project Structure

### Glitch-Specific Stuff

The `glitch.json` file tells when and how to run the `glitch/install.sh` and `glitch/start.sh` scripts to power this application.

To keep the project clean and avoid Glitch's 200MB project size limit we do all of our Rust installation, compilation, etc. in the container's `/tmp` directory.

References that were useful:

* [Glitch Forums: Language support on Glitch: a list](https://support.glitch.com/t/language-support-on-glitch-a-list/5466)
* [Glitch Help Center: What technical restrictions are in place?](https://glitch.com/help/restrictions/)
* [Glitch Help Center: Can I change which files cause my app to restart?](https://glitch.com/help/restart/)

### Rust and Actix

The project's basic Rust skeleton was created, as follows:

```
$ cargo new --bin ./hello-rust-actix && mv ./hello-rust-actix/* ./ && rmdir hello-rust-actix
     Created binary (application) `./hello-rust-actix` project
```

From there, I just followed the basic instructions on <https://doc.rust-lang.org/book/ch01-03-hello-cargo.html> and <https://actix.rs/docs/getting-started/>.

## Speed Up the Install/Launch?

It should be possible to dramatically speed up the install/launch time by making aggressive use of
build caching using an external store like S3. Not yet implemented, though.