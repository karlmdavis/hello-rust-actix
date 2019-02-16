use std::env;
extern crate actix_web;
use actix_web::{server, App, HttpRequest, HttpResponse, http::Method, http};
extern crate askama;
use askama::Template;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
  count: usize,
}

fn index(req: &HttpRequest<AppState>) -> HttpResponse {
  let count = req.state().counter.fetch_add(0, Ordering::Relaxed);
  let index = IndexTemplate { count };
  let html = index.render().unwrap();
  HttpResponse::Ok()
    .content_type("text/html")
    .body(html)
}

struct AppState {
  counter: Arc<AtomicUsize>,
}

fn increment(req: &HttpRequest<AppState>) -> HttpResponse {
  req.state().counter.fetch_add(1, Ordering::Relaxed);
  HttpResponse::Found()
    .header(http::header::LOCATION, "/")
    .finish()
}

fn howdy(_req: &HttpRequest<AppState>) -> &'static str {
  "You are clearly a fantastic person. Thanks for being you!"
}

fn main() {
  let counter = Arc::new(AtomicUsize::new(0));
  
  server::new(move || {
    App::with_state(AppState{ counter: counter.clone() })
      .resource("/", |r| r.f(index))
      .resource("/increment", move |r| r.method(Method::POST).f(increment))
      .resource("/howdy", |r| r.f(howdy))
  })
    .bind(format!("127.0.0.1:{}", env::var("PORT").unwrap_or("3000".to_string())))
    .unwrap()
    .run();
}