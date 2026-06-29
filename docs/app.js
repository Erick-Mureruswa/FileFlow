// ===== Config =====
// To collect waitlist emails, create a free form at https://formspree.io,
// then paste its endpoint below (looks like https://formspree.io/f/abcdwxyz).
// Until then, the form falls back to opening the visitor's email app.
const WAITLIST_ENDPOINT = "https://formspree.io/f/REPLACE_WITH_FORM_ID";
const NOTIFY_EMAIL = "erickmureruswa@gmail.com";

// ===== Nav background on scroll =====
const nav = document.getElementById("nav");
const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 8);
onScroll();
window.addEventListener("scroll", onScroll, { passive: true });

// ===== Scroll reveal =====
const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const revealables = document.querySelectorAll(".reveal");
if (reduce || !("IntersectionObserver" in window)) {
  revealables.forEach((el) => el.classList.add("in"));
} else {
  const io = new IntersectionObserver(
    (entries, obs) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          obs.unobserve(e.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
  );
  revealables.forEach((el) => io.observe(el));
}

// ===== Waitlist =====
const form = document.getElementById("waitlist-form");
const msg = document.getElementById("form-msg");
const input = document.getElementById("email");

const validEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

const setMsg = (text, kind) => {
  msg.textContent = text;
  msg.className = "form-msg" + (kind ? " " + kind : "");
};

const markJoined = () => {
  form.innerHTML =
    '<p class="form-msg ok" role="status">You are on the list. We will email you when FileFlow hits Google Play.</p>';
};

if (localStorage.getItem("ff_waitlisted") === "1") {
  markJoined();
}

const mailtoFallback = (email) => {
  const subject = encodeURIComponent("FileFlow waitlist");
  const body = encodeURIComponent("Please add me to the FileFlow waitlist: " + email);
  window.location.href = `mailto:${NOTIFY_EMAIL}?subject=${subject}&body=${body}`;
};

form?.addEventListener("submit", async (e) => {
  e.preventDefault();
  const email = input.value.trim();
  if (!validEmail(email)) {
    setMsg("Please enter a valid email address.", "err");
    input.focus();
    return;
  }

  const submitBtn = form.querySelector("button[type=submit]");
  submitBtn.disabled = true;
  setMsg("Adding you...", null);

  // No form backend configured yet: hand off to the visitor's email app.
  if (WAITLIST_ENDPOINT.includes("REPLACE_WITH")) {
    mailtoFallback(email);
    localStorage.setItem("ff_waitlisted", "1");
    markJoined();
    return;
  }

  try {
    const res = await fetch(WAITLIST_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ email }),
    });
    if (!res.ok) throw new Error("Request failed");
    localStorage.setItem("ff_waitlisted", "1");
    markJoined();
  } catch (_) {
    submitBtn.disabled = false;
    setMsg("That did not go through. Opening your email app instead.", "err");
    mailtoFallback(email);
  }
});
