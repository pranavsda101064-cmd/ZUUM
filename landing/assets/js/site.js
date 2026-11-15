(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var header = document.querySelector(".site-header");
  var body = document.body;
  var root = document.documentElement;

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  /* Navigation surface */
  function updateHeader() {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 24);
  }

  function updateScrollProgress() {
    var max = root.scrollHeight - window.innerHeight;
    var progress = max > 0 ? window.scrollY / max : 0;
    root.style.setProperty("--scroll-progress", clamp(progress, 0, 1).toFixed(4));
  }

  function updateHero() {
    var heroes = document.querySelectorAll("[data-hero]");
    heroes.forEach(function (hero) {
      var rect = hero.getBoundingClientRect();
      var progress = clamp(-rect.top / Math.max(rect.height, 1), 0, 1);
      hero.style.setProperty("--hero-progress", progress.toFixed(4));
    });
  }

  /* Pointer parallax on the hero visual */
  var hero = document.querySelector("[data-hero]");
  if (hero && !reduceMotion && window.matchMedia("(pointer: fine)").matches) {
    var pointerFrame = false;
    var pointerX = 0;
    var pointerY = 0;

    function applyPointer() {
      hero.style.setProperty("--mouse-x", pointerX.toFixed(3));
      hero.style.setProperty("--mouse-y", pointerY.toFixed(3));
      pointerFrame = false;
    }

    hero.addEventListener("pointermove", function (event) {
      var rect = hero.getBoundingClientRect();
      pointerX = clamp(((event.clientX - rect.left) / rect.width - 0.5) * 2, -1, 1);
      pointerY = clamp(((event.clientY - rect.top) / rect.height - 0.5) * 2, -1, 1);
      if (!pointerFrame) {
        pointerFrame = true;
        window.requestAnimationFrame(applyPointer);
      }
    });

    hero.addEventListener("pointerleave", function () {
      pointerX = 0;
      pointerY = 0;
      hero.style.setProperty("--mouse-x", "0");
      hero.style.setProperty("--mouse-y", "0");
    });
  }

  /* Mobile menu */
  var menuToggle = document.querySelector("[data-menu-toggle]");
  var menu = document.getElementById("site-menu");
  var lastFocused = null;

  function focusables() {
    if (!menu) return [];
    var items = Array.prototype.slice.call(menu.querySelectorAll("a[href], button:not([disabled])"));
    if (menuToggle) items.push(menuToggle);
    return items;
  }

  function openMenu() {
    if (!menu || !menuToggle) return;
    lastFocused = document.activeElement;
    body.classList.add("menu-open");
    menuToggle.setAttribute("aria-expanded", "true");
    var items = focusables();
    if (items.length) window.setTimeout(function () { items[0].focus(); }, 120);
  }

  function closeMenu(returnFocus) {
    if (!menu || !menuToggle) return;
    body.classList.remove("menu-open");
    menuToggle.setAttribute("aria-expanded", "false");
    if (returnFocus && lastFocused instanceof HTMLElement) lastFocused.focus();
  }

  if (menuToggle && menu) {
    menuToggle.addEventListener("click", function () {
      if (body.classList.contains("menu-open")) closeMenu(true);
      else openMenu();
    });

    menu.querySelectorAll("a[href]").forEach(function (link) {
      link.addEventListener("click", function () { closeMenu(false); });
    });

    document.addEventListener("keydown", function (event) {
      if (!body.classList.contains("menu-open")) return;
      if (event.key === "Escape") {
        event.preventDefault();
        closeMenu(true);
        return;
      }
      if (event.key !== "Tab") return;
      var items = focusables();
      if (!items.length) return;
      var first = items[0];
      var last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth >= 900) closeMenu(false);
    });
  }

  /* Scroll reveals */
  var revealItems = Array.prototype.slice.call(document.querySelectorAll(".reveal"));
  if ("IntersectionObserver" in window) {
    var revealObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });

    revealItems.forEach(function (item) { revealObserver.observe(item); });
  } else {
    revealItems.forEach(function (item) { item.classList.add("is-visible"); });
  }

  /* Tagline: light each word as it crosses the trigger line */
  var tagline = document.querySelector("[data-tagline]");
  var taglineWords = [];
  if (tagline) {
    var source = tagline.textContent.trim().replace(/\s+/g, " ");
    var parts = source.split(" ");
    tagline.textContent = "";
    parts.forEach(function (part, index) {
      var word = document.createElement("span");
      word.className = "word";
      word.textContent = part;
      word.style.setProperty("--word-index", String(index));
      tagline.appendChild(word);
      if (index < parts.length - 1) tagline.appendChild(document.createTextNode(" "));
      taglineWords.push(word);
    });
    tagline.classList.add("tagline--armed");
  }

  function updateTagline() {
    if (!taglineWords.length) return;
    var line = window.innerHeight * 0.72;
    taglineWords.forEach(function (word) {
      var rect = word.getBoundingClientRect();
      word.classList.toggle("is-lit", rect.top < line);
    });
  }

  /* Steps: mark the step crossing mid viewport and sync the phone chip */
  var steps = Array.prototype.slice.call(document.querySelectorAll("[data-step]"));
  var stepLabel = document.querySelector("[data-step-label]");
  var stepPhone = document.querySelector("[data-step-phone]");
  if ("IntersectionObserver" in window && steps.length) {
    var stepObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        steps.forEach(function (step) {
          step.classList.toggle("is-active", step === entry.target);
        });
        var label = entry.target.getAttribute("data-label");
        if (label) {
          if (stepLabel) stepLabel.textContent = label;
          if (stepPhone) stepPhone.setAttribute("data-active-step", label);
        }
      });
    }, { rootMargin: "-45% 0px -45% 0px", threshold: 0 });

    steps.forEach(function (step) { stepObserver.observe(step); });
  }

  /* Parallax: transform only, throttled through requestAnimationFrame */
  var parallaxItems = Array.prototype.slice.call(document.querySelectorAll("[data-parallax]")).map(function (element) {
    var speed = parseFloat(element.getAttribute("data-parallax"));
    return {
      element: element,
      speed: isNaN(speed) ? 0.1 : speed,
      anchor: element.closest("[data-parallax-anchor]") || element.parentElement
    };
  });

  function updateParallax() {
    if (reduceMotion || !parallaxItems.length) return;
    var viewport = window.innerHeight;
    var scale = window.innerWidth < 760 ? 0.7 : 1;

    parallaxItems.forEach(function (item) {
      var anchor = item.anchor;
      if (!anchor) return;
      var rect = anchor.getBoundingClientRect();
      if (rect.bottom < -240 || rect.top > viewport + 240) return;
      var progress = (rect.top + rect.height / 2 - viewport / 2) / viewport;
      var offset = progress * item.speed * 320 * scale;
      item.element.style.setProperty("--parallax-y", offset.toFixed(2) + "px");
    });
  }

  /* 3D tilt on cards */
  var tiltCards = Array.prototype.slice.call(document.querySelectorAll("[data-tilt]"));
  if (!reduceMotion && window.matchMedia("(pointer: fine)").matches) {
    tiltCards.forEach(function (card) {
      card.addEventListener("pointermove", function (event) {
        var rect = card.getBoundingClientRect();
        var x = (event.clientX - rect.left) / rect.width - 0.5;
        var y = (event.clientY - rect.top) / rect.height - 0.5;
        card.style.setProperty("--tilt-x", (-y * 5).toFixed(2) + "deg");
        card.style.setProperty("--tilt-y", (x * 7).toFixed(2) + "deg");
      });

      card.addEventListener("pointerleave", function () {
        card.style.setProperty("--tilt-x", "0deg");
        card.style.setProperty("--tilt-y", "0deg");
      });
    });
  }

  /* Fleet carousel */
  function initCarousel(carousel) {
    var track = carousel.querySelector("[data-carousel-track]");
    if (!track) return;
    var cards = Array.prototype.slice.call(track.children);
    if (!cards.length) return;

    var prev = carousel.querySelector("[data-carousel-prev]");
    var next = carousel.querySelector("[data-carousel-next]");
    var dotsWrap = carousel.querySelector("[data-carousel-dots]");
    var status = carousel.querySelector("[data-carousel-status]");
    var autoplayMs = parseInt(carousel.getAttribute("data-carousel-autoplay") || "0", 10);
    var index = 0;
    var dots = [];
    var hover = false;
    var focused = false;
    var inView = false;
    var lastManual = 0;
    var syncFrame = false;

    function stepWidth() {
      var styles = window.getComputedStyle(track);
      var gap = parseFloat(styles.columnGap || styles.gap || "0");
      return cards[0].getBoundingClientRect().width + gap;
    }

    function markManual() {
      lastManual = Date.now();
    }

    function goTo(target, immediate) {
      var bounded = clamp(target, 0, cards.length - 1);
      track.scrollTo({
        left: bounded * stepWidth(),
        behavior: immediate || reduceMotion ? "auto" : "smooth"
      });
    }

    function setIndex(target) {
      index = clamp(target, 0, cards.length - 1);
      if (prev) prev.disabled = index === 0;
      if (next) next.disabled = index === cards.length - 1;
      dots.forEach(function (dot, dotIndex) {
        var active = dotIndex === index;
        dot.classList.toggle("is-active", active);
        if (active) dot.setAttribute("aria-current", "true");
        else dot.removeAttribute("aria-current");
      });
      if (status) {
        var title = cards[index].getAttribute("data-title") || String(index + 1);
        status.textContent = "Slide " + (index + 1) + " of " + cards.length + ": " + title;
      }
    }

    function sync() {
      if (syncFrame) return;
      syncFrame = true;
      window.requestAnimationFrame(function () {
        var width = stepWidth();
        if (width > 0) setIndex(Math.round(track.scrollLeft / width));
        syncFrame = false;
      });
    }

    if (dotsWrap) {
      cards.forEach(function (card, cardIndex) {
        var dot = document.createElement("button");
        dot.type = "button";
        dot.className = "rail-dot";
        dot.setAttribute("aria-label", "Go to slide " + (cardIndex + 1) + ": " + (card.getAttribute("data-title") || ""));
        dot.addEventListener("click", function () {
          markManual();
          goTo(cardIndex);
        });
        dotsWrap.appendChild(dot);
        dots.push(dot);
      });
    }

    if (prev) prev.addEventListener("click", function () { markManual(); goTo(index - 1); });
    if (next) next.addEventListener("click", function () { markManual(); goTo(index + 1); });

    track.addEventListener("keydown", function (event) {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        markManual();
        goTo(index - 1);
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        markManual();
        goTo(index + 1);
      } else if (event.key === "Home") {
        event.preventDefault();
        markManual();
        goTo(0);
      } else if (event.key === "End") {
        event.preventDefault();
        markManual();
        goTo(cards.length - 1);
      }
    });

    track.addEventListener("scroll", sync, { passive: true });
    track.addEventListener("pointerdown", markManual);

    carousel.addEventListener("pointerenter", function (event) {
      if (event.pointerType === "mouse") hover = true;
    });
    carousel.addEventListener("pointerleave", function (event) {
      if (event.pointerType === "mouse") hover = false;
    });
    carousel.addEventListener("focusin", function () { focused = true; });
    carousel.addEventListener("focusout", function (event) {
      if (!carousel.contains(event.relatedTarget)) focused = false;
    });

    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) {
        inView = entries[0].isIntersecting;
      }, { threshold: 0.2 }).observe(carousel);
    } else {
      inView = true;
    }

    if (autoplayMs > 0 && !reduceMotion) {
      window.setInterval(function () {
        if (hover || focused || inView === false || document.hidden) return;
        if (Date.now() - lastManual < 4500) return;
        goTo(index >= cards.length - 1 ? 0 : index + 1);
      }, autoplayMs);
    }

    window.addEventListener("resize", function () {
      goTo(index, true);
    });

    setIndex(0);
  }

  Array.prototype.slice.call(document.querySelectorAll("[data-carousel]")).forEach(initCarousel);

  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      updateHeader();
      updateScrollProgress();
      updateHero();
      updateTagline();
      updateParallax();
      ticking = false;
    });
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll);
  updateHeader();
  updateScrollProgress();
  updateHero();
  updateTagline();
  updateParallax();

  /* Install links: keep the icon useful even before the APK is published */
  var toast = document.querySelector("[data-toast]");
  var toastTimer = null;

  function showToast(message) {
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add("is-visible");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () {
      toast.classList.remove("is-visible");
    }, 5200);
  }

  function canDownload(url) {
    return fetch(url, { method: "HEAD", cache: "no-store" }).then(function (response) {
      var type = response.headers.get("content-type") || "";
      return response.ok && type.indexOf("text/html") === -1;
    }).catch(function () {
      return false;
    });
  }

  function startDownload(url) {
    var anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = url.split("/").pop() || "zuum.apk";
    anchor.rel = "noopener";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  var installMessage = "The Android build is not public yet. Keep the icon handy, it will open the download when it ships.";

  document.querySelectorAll("[data-install]").forEach(function (link) {
    var url = link.getAttribute("data-download");
    if (!url) return;

    link.addEventListener("click", function (event) {
      event.preventDefault();
      if (link.getAttribute("data-available") === "true") {
        startDownload(url);
        return;
      }
      canDownload(url).then(function (available) {
        link.setAttribute("data-available", available ? "true" : "false");
        if (available) startDownload(url);
        else showToast(installMessage);
      });
    });
  });

  /* Footer year */
  document.querySelectorAll("[data-year]").forEach(function (node) {
    node.textContent = String(new Date().getFullYear());
  });
})();
