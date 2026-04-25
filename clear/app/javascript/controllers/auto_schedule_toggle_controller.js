import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle", "manual", "preview"];

  connect() {
    this.sync();
  }

  sync() {
    const auto = this.toggleTarget.checked;
    this.manualTargets.forEach((el) => {
      el.classList.toggle("hidden", auto);
      el.querySelectorAll("input, select, textarea").forEach((input) => {
        input.disabled = auto;
      });
    });
    this.refreshPreview();
  }

  toggle() {
    this.sync();
  }

  previewIfReady() {
    if (this.toggleTarget.checked) this.refreshPreview();
  }

  async refreshPreview() {
    if (!this.hasPreviewTarget) return;

    if (!this.toggleTarget.checked) {
      this.previewTarget.textContent = "";
      this.previewTarget.classList.add("hidden");
      return;
    }

    const duration = this.readDuration();
    this.previewTarget.classList.remove("hidden");

    if (!duration) {
      this.previewTarget.textContent = "Pick a duration to see the proposed slot.";
      return;
    }

    this.previewTarget.textContent = "Finding a slot…";

    try {
      const res = await fetch(`/auto_schedule/preview?duration_minutes=${duration}`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      });
      const data = await res.json();
      this.previewTarget.textContent = data.ok
        ? `Will place: ${data.formatted}`
        : (data.message || "No open slot found.");
    } catch (e) {
      this.previewTarget.textContent = "Couldn't load preview.";
    }
  }

  readDuration() {
    const hidden = this.element.querySelector('input.dropdown-input[name$="[duration_minutes]"]');
    const value = hidden?.value ? parseInt(hidden.value, 10) : NaN;
    return Number.isFinite(value) && value > 0 ? value : null;
  }
}
