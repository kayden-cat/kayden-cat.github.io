"use strict";

const home = document.querySelector(".home-art");
const homeData = document.querySelector("#home-works");
if (home && homeData) {
  try {
    const works = JSON.parse(homeData.textContent);
    if (works.length) {
      const work = works[Math.floor(Math.random() * works.length)];
      const image = home.querySelector("img");
      home.querySelector("a").href = work.href;
      home.querySelector("source").srcset = work.webp;
      image.src = work.jpg;
      image.width = work.w;
      image.height = work.h;
      image.alt = work.title;
      home.querySelector("figcaption").textContent = work.title + (work.year ? ", " + work.year : "") + (work.video ? " — video" : "");
    }
  } catch (error) {
    // Keep the server-rendered fallback visible if the data cannot be read.
    console.error("Unable to select a home artwork", error);
  } finally {
    home.classList.add("is-ready");
  }
}

const header = document.querySelector(".site-header");
const toggle = document.querySelector(".menu-toggle");
const nav = document.querySelector(".nav");
const dropdown = document.querySelector(".nav__item--has-sub");
function closeMenu() {
  header.classList.remove("is-open");
  toggle.setAttribute("aria-expanded", "false");
}
toggle.addEventListener("click", () => {
  const open = header.classList.toggle("is-open");
  toggle.setAttribute("aria-expanded", String(open));
});
nav.addEventListener("click", event => { if (event.target.closest("a")) closeMenu(); });
document.addEventListener("keydown", event => {
  if (event.key !== "Escape") return;
  if (header.classList.contains("is-open")) { closeMenu(); toggle.focus(); }
  else if (dropdown.contains(document.activeElement) || dropdown.matches(":hover")) {
    // Restore focus only when it is inside; do so before hiding to avoid a reset.
    if (dropdown.contains(document.activeElement)) dropdown.querySelector(".nav__link").focus();
    dropdown.classList.add("is-dismissed");
  }
});
// Hiding the submenu can itself trigger mouseleave; keep Escape effective while focused.
dropdown.addEventListener("mouseleave", () => {
  if (!dropdown.contains(document.activeElement)) dropdown.classList.remove("is-dismissed");
});
dropdown.addEventListener("focusout", event => { if (!dropdown.contains(event.relatedTarget)) dropdown.classList.remove("is-dismissed"); });
matchMedia("(min-width: 768px)").addEventListener("change", event => { if (event.matches) closeMenu(); });

