import { Controller } from "@hotwired/stimulus"

const DASHBOARD_VIEW_TOGGLE_NAME = "calendar_dashboard"
const VIEWS = ["weekly", "monthly", "yearly", "daily"]

export default class extends Controller {
  static targets = ["weeklyWrapper", "monthlyWrapper", "yearMarker", "dayMarker"]
  static values = { baseUrl: String }

  connect() {
    // The year frame is rendered server-side when the saved view is yearly (the server
    // reads the same cookie), so the marker is authoritative here — no fetch, no flash.
    if (this.hasYearMarkerTarget) {
      this.currentView = "yearly"
      this.syncToggleDropdowns()
      return
    }

    // The day frame is likewise server-rendered (it carries a single day's grid, not the
    // weekly/monthly wrappers), so its marker is authoritative — same pattern as yearly.
    if (this.hasDayMarkerTarget) {
      this.currentView = "daily"
      this.syncToggleDropdowns()
      return
    }

    // Otherwise the server rendered the weekly/monthly frame (both in the DOM). The cookie
    // only ever distinguishes weekly vs monthly here — yearly was already handled server-side
    // — so pick the wrapper to show instantly. Anything but "monthly" coerces to weekly.
    this.currentView = this.savedView() === "monthly" ? "monthly" : "weekly"
    this.syncView()
  }

  toggle(event) {
    const nextView = event?.detail?.value || event?.target?.value
    if (!VIEWS.includes(nextView)) return

    this.currentView = nextView
    // Persist every view (incl. yearly) in a cookie the server reads, so the next bare
    // /calendar renders the last view directly — see DashboardController#saved_calendar_view.
    this.persistView(nextView)

    if (nextView === "yearly" || nextView === "daily") {
      this.navigateToView(nextView)        // server-rendered views — weekly/monthly aren't in the DOM yet, fetch
    } else if (this.hasYearMarkerTarget || this.hasDayMarkerTarget) {
      this.navigateToView(null)            // leaving a server-rendered frame — fetch weekly/monthly back
    } else {
      this.syncView()                      // weekly <-> monthly are both present — instant
      if (event?.detail) this.focusActiveViewToggle()
    }
  }

  // View preference persistence. A cookie (not localStorage) so the server can read it on a
  // bare /calendar and render the saved view directly. Lax + 1yr, mirrors the old stickiness.
  persistView(view) {
    document.cookie = `calendar_view=${view}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`
  }

  savedView() {
    const match = document.cookie.match(/(?:^|;\s*)calendar_view=([^;]+)/)
    return match ? decodeURIComponent(match[1]) : null
  }

  // Navigate the dashboard_calendar frame, preserving start_date/filter. Reuses the
  // detached-anchor pattern (see course_filter_controller) so controllers outside the
  // frame are untouched; advance pushes history so the view survives reload.
  navigateToView(view) {
    const base = (this.hasBaseUrlValue && this.baseUrlValue) || window.location.pathname
    const url  = new URL(base, window.location.origin)
    const here = new URL(window.location.href)

    if (view) {
      url.searchParams.set("view", view)
    } else {
      url.searchParams.delete("view")
    }

    const startDate = here.searchParams.get("start_date")
    const filter    = here.searchParams.get("filter")
    if (startDate) url.searchParams.set("start_date", startDate)
    if (filter) url.searchParams.set("filter", filter)

    const a = document.createElement("a")
    a.href = url.toString()
    a.dataset.turboFrame  = "dashboard_calendar"
    a.dataset.turboAction = "advance"
    document.body.appendChild(a)
    a.click()
    a.remove()
  }

  syncView() {
    const isMonthly = this.currentView === "monthly"

    if (this.hasWeeklyWrapperTarget) {
      this.weeklyWrapperTarget.classList.toggle("hidden", isMonthly)
      this.weeklyWrapperTarget.style.display = isMonthly ? "none" : ""
    }
    if (this.hasMonthlyWrapperTarget) {
      this.monthlyWrapperTarget.style.display = isMonthly ? "flex" : "none"
      this.monthlyWrapperTarget.classList.toggle("hidden", !isMonthly)
    }

    this.syncToggleDropdowns()
  }

  syncToggleDropdowns() {
    this.element.querySelectorAll('[data-controller~="dropdown"]').forEach((dropdown) => {
      const input = dropdown.querySelector(`input.dropdown-input[name="${DASHBOARD_VIEW_TOGGLE_NAME}"]`)
      if (!input) return

      input.value = this.currentView

      const items = dropdown.querySelectorAll(".dropdown-item")
      items.forEach((item) => {
        item.dataset.selected = "false"
      })

      const selected = dropdown.querySelector(`.dropdown-item[data-dropdown-value-param="${this.currentView}"]`)
      if (!selected) return

      selected.dataset.selected = "true"

      const label = dropdown.querySelector(".dropdown-label")
      if (!label) return

      label.textContent = selected.dataset.dropdownLabelParam || selected.textContent.trim()
    })
  }

  focusActiveViewToggle() {
    const activeWrapper = this.currentView === "monthly"
      ? (this.hasMonthlyWrapperTarget ? this.monthlyWrapperTarget : null)
      : (this.hasWeeklyWrapperTarget ? this.weeklyWrapperTarget : null)
    if (!activeWrapper) return

    const activeInput = activeWrapper.querySelector(`input.dropdown-input[name="${DASHBOARD_VIEW_TOGGLE_NAME}"]`)
    const toggleButton = activeInput?.closest('[data-controller~="dropdown"]')?.querySelector(".dropdown-toggle")
    if (!toggleButton) return

    requestAnimationFrame(() => {
      toggleButton.focus({ preventScroll: true })
    })
  }
}
