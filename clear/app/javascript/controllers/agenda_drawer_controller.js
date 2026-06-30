import { Controller } from "@hotwired/stimulus";

const PANEL_WIDTH = 360; // fixed: keeps the calendar from reflowing as frame content loads
const PANEL_GAP = 16;    // gap between the calendar and the fixed panel

export default class extends Controller {
  static targets = ["panel", "frame", "skeleton", "spacer"];
  static values = {
    url: String,
    projectId: Number,
  };

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close();
    };
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
  }

  open(e) {
    e?.preventDefault?.();
    const date = e?.params?.date || e?.currentTarget?.dataset?.date || null;
    const projectId = e?.params?.projectId || null;
    if (projectId) this.projectIdValue = projectId;
    this.openForDate(date);
  }

  openForDate(date) {
    const url = this.buildUrl(date);

    this.panelTarget.style.visibility = "visible";
    this.panelTarget.style.width = `${PANEL_WIDTH}px`;
    // Reserve the panel's width (plus a gap) in the flow so the calendar is
    // pushed narrower; the panel itself is position:fixed and pinned.
    if (this.hasSpacerTarget) this.spacerTarget.style.width = `${PANEL_WIDTH + PANEL_GAP}px`;

    if (this.frameTarget.src !== url) {
      this.frameTarget.src = url;
    } else {
      this.frameTarget.reload();
    }
  }

  close() {
    this.panelTarget.style.width = "0px";
    if (this.hasSpacerTarget) this.spacerTarget.style.width = "0px";
    window.setTimeout(() => {
      this.panelTarget.style.visibility = "hidden";
    }, 300);
    window.dispatchEvent(new CustomEvent("agenda:clear"));
  }

  showSkeleton() {
    if (!this.hasSkeletonTarget) return;
    this.frameTarget.innerHTML = this.skeletonTarget.innerHTML;
  }

  frameLoaded() {
    // Width is fixed; nothing to recompute. Kept so the frame action stays valid.
  }

  buildUrl(date) {
    const u = new URL(this.urlValue, window.location.origin);
    if (date) u.searchParams.set("date", date);
    if (this.projectIdValue) u.searchParams.set("project_id", this.projectIdValue);
    return u.toString();
  }
}
