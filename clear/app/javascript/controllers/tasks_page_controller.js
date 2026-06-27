import { Controller } from "@hotwired/stimulus"

// Drives the Tasks page mockup: tab switching (List / Breakdown / Missed) with
// last-view persistence, the New-task drawer, accordion cards, and client-side
// task completion that stays in sync across every pane a task appears in.
// Data is server-rendered sample data; nothing persists to a backend yet.
export default class extends Controller {
  static targets = ["tab", "pane", "drawer", "scrim"]

  connect() {
    this._onKey = (e) => {
      if (e.key === "Escape") this.closeDrawer()
    }
    document.addEventListener("keydown", this._onKey)

    // Restore the last-used view (List by default).
    const saved = this.readView()
    if (saved && this.tabTargets.some((t) => t.dataset.tab === saved)) {
      this.activate(saved)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
  }

  switch(event) {
    const tab = event.currentTarget.dataset.tab
    this.activate(tab)
    this.writeView(tab)
  }

  activate(tab) {
    this.tabTargets.forEach((t) => t.classList.toggle("is-active", t.dataset.tab === tab))
    this.paneTargets.forEach((p) => p.classList.toggle("hidden", p.dataset.pane !== tab))
  }

  readView() {
    try { return localStorage.getItem("clearTasksView") } catch (e) { return null }
  }

  writeView(tab) {
    try { localStorage.setItem("clearTasksView", tab) } catch (e) { /* ignore */ }
  }

  toggleCard(event) {
    // Don't collapse when an inner control (e.g. "Break down with AI") is clicked.
    if (event.target.closest("[data-no-toggle]")) return
    event.currentTarget.closest(".tsk-card").classList.toggle("is-collapsed")
  }

  // Toggle completion for a task across every pane it renders in, then refresh
  // the Breakdown progress bars and the Missed list/count.
  toggleDone(event) {
    const row = event.currentTarget.closest(".tsk-row")
    if (!row) return
    const id = row.dataset.taskId
    const done = !event.currentTarget.classList.contains("is-done")

    this.element.querySelectorAll(`[data-task-id="${id}"]`).forEach((r) => {
      const cbx = r.querySelector(".tsk-cbx")
      const title = r.querySelector(".tsk-row-title")
      if (cbx) cbx.classList.toggle("is-done", done)
      if (title) {
        title.classList.toggle("text-zinc-500", done)
        title.classList.toggle("line-through", done)
        title.classList.toggle("text-zinc-100", !done)
      }
      // A missed task drops out of the Missed list the moment it's done.
      if (r.classList.contains("tsk-missed-row")) r.classList.toggle("hidden", done)
    })

    this.refreshProgress()
    this.refreshMissed()
  }

  refreshProgress() {
    this.element.querySelectorAll(".tsk-card").forEach((card) => {
      const prog = card.querySelector(".tsk-prog")
      if (!prog) return
      const rows = card.querySelectorAll(".tsk-card-body [data-task-id]")
      const total = rows.length
      const done = card.querySelectorAll(".tsk-card-body [data-task-id] .tsk-cbx.is-done").length
      const pct = total === 0 ? 0 : Math.round((done / total) * 100)
      const fill = prog.querySelector(".fill")
      const ptxt = prog.querySelector(".ptxt")
      if (fill) fill.style.width = `${pct}%`
      if (ptxt) ptxt.textContent = `${done} of ${total} done`
    })
  }

  refreshMissed() {
    const pane = this.element.querySelector('[data-pane="missed"]')
    if (!pane) return
    const rows = pane.querySelectorAll(".tsk-missed-row")
    let visible = 0
    rows.forEach((r) => { if (!r.classList.contains("hidden")) visible++ })

    const badge = this.element.querySelector('[data-count="missed"]')
    if (badge) badge.textContent = visible

    const list = pane.querySelector("[data-missed-list]")
    const empty = pane.querySelector("[data-missed-empty]")
    if (list) list.classList.toggle("hidden", visible === 0)
    if (empty) empty.classList.toggle("hidden", visible !== 0)
  }

  openDrawer() {
    this.drawerTarget.classList.add("is-open")
    this.scrimTarget.classList.add("is-on")
  }

  closeDrawer() {
    this.drawerTarget.classList.remove("is-open")
    this.scrimTarget.classList.remove("is-on")
  }
}
