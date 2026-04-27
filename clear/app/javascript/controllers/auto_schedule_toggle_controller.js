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
    const weekdays = this.readWeekdays();
    const repeatUntil = this.readRepeatUntil();
    const priority = this.readPriority();
    this.previewTarget.classList.remove("hidden");

    if (!duration) {
      this.previewTarget.textContent = "Pick a duration to see the proposed slot.";
      return;
    }

    this.previewTarget.textContent = "Finding a slot…";

    const params = new URLSearchParams();
    params.set("duration_minutes", duration);
    weekdays.forEach((w) => params.append("weekdays[]", w));
    if (repeatUntil) params.set("repeat_until", repeatUntil);
    if (priority) params.set("priority", priority);

    try {
      const res = await fetch(`/auto_schedule/preview?${params.toString()}`, {
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

  readWeekdays() {
    const recurring = this.element.querySelector('input[type="checkbox"][name$="[recurring]"]');
    if (!recurring?.checked) return [];

    const days = this.element.querySelectorAll('input[type="checkbox"][name$="[repeat_days][]"]:checked');
    return Array.from(days)
      .map((d) => parseInt(d.value, 10))
      .filter((n) => Number.isFinite(n));
  }

  readRepeatUntil() {
    const recurring = this.element.querySelector('input[type="checkbox"][name$="[recurring]"]');
    if (!recurring?.checked) return null;

    const field = this.element.querySelector('input[type="date"][name$="[repeat_until]"]');
    return field?.value || null;
  }

  readPriority() {
    const field = this.element.querySelector('input[name$="[priority]"]');
    return field?.value?.trim() || null;
  }
}
