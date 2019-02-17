# "Hello World!" via Rust and Actix

This Glitch project is a proof of concept for using Glitch with Rust, and specifically using Rust's [Actix](https://actix.rs/) web framework to run a simple "Hello World!" backend web application.

It turns out that Glitch and Rust aren't quite a match made in heaven: Glitch containers just don't quite have the "oomph" needed for a smooth compilation experience. Nonetheless, it works! (Mostly.)

## Mostly? What Do You Mean That it _Mostly_ Works?

Well, building everything from a cold start with no S3 cache will take about an hour. That's... pretty bad.

It's a lot better with an S3 cache present, though! Check out the project on GitHub here: <https://github.com/karlmdavis/hello-rust-actix>. The `master` branch over there has an `infra/` directory with Ansible scripts to setup the caching infrastructure in AWS for you: basically just an S3 bucket that the Glitch app can read from and write to. Once you have that setup, open up the `.env` file in Glitch and set the `AWS_S3_CACHE_BUCKET`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` variables. After that, the project's install & compile loops drop down to 4 minutes or so, even from a cold start. Yay!

(I mean, it's still not _great_, but it's at least workable, given that Glitch only forces a cold start every 12 hours or so.)

There is one other niggle, though: the `cargo`/`rustc` compile cycle uses more than 500 MB of RAM (when there's no cache present). In debug mode, it does seem to eventually sneak past Glitch's process killer and succeed. But I can't reliably get a `--release` build of the project to succeed

`:shrug:` Oh well.

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

## License

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
