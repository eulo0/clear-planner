import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay", "panel", "frame"];
  static values = {
    url: String
  };

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close();
    };
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
    this._observer?.disconnect();
  }

  open(e) {
    e?.preventDefault?.();

    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none");
    this.overlayTarget.classList.add("opacity-100");

    this.panelTarget.classList.remove("translate-x-[120%]");
    this.panelTarget.classList.add("translate-x-0");
    this.panelTarget.style.width = "600px";

    if (!this.frameTarget.src) {
      this.frameTarget.src = this.urlValue;
    }

    this.frameTarget.addEventListener("turbo:frame-load", () => {
      this.scrollToBottom();
      this.observeMessages();
    }, { once: true });
  }

  close() {
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none");
    this.overlayTarget.classList.remove("opacity-100");

    this.panelTarget.classList.add("translate-x-[120%]");
    this.panelTarget.classList.remove("translate-x-0");

    window.setTimeout(() => {
      this.panelTarget.style.width = "0px";
    }, 300);
  }

  observeMessages() {
    const messages = document.getElementById("project_messages");
    if (!messages) return;

    this._observer?.disconnect();
    this._observer = new MutationObserver(() => this.scrollToBottom());
    this._observer.observe(messages, { childList: true });
  }

  scrollToBottom() {
    const messages = document.getElementById("project_messages");
    if (messages) messages.scrollTop = messages.scrollHeight;
  }

  sendOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      event.target.closest("form")?.requestSubmit();
    }
  }
}