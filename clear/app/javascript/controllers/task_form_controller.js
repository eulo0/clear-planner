import { Controller } from "@hotwired/stimulus"

// Drives cascading course → course-item dropdowns in task create/edit forms.
// Listens for `dropdown:select` from the course dropdown (scoped by a wrapper
// div) and rebuilds the course-item dropdown's menu items accordingly.
export default class extends Controller {
  static targets = ["courseItemWrapper", "courseCol"]
  static values = { grouped: Object }

  courseSelected(event) {
    const courseId = event.detail.value
    const items = courseId ? (this.groupedValue[courseId] || []) : []

    if (!items.length) {
      this.courseColTarget.classList.add("col-span-2")
      this.courseItemWrapperTarget.classList.add("hidden")
      const input = this.courseItemWrapperTarget.querySelector(".dropdown-input")
      if (input) input.value = ""
      return
    }

    this.courseColTarget.classList.remove("col-span-2")
    this.courseItemWrapperTarget.classList.remove("hidden")
    this._rebuildMenu(items)

    const label = this.courseItemWrapperTarget.querySelector('[data-dropdown-target="label"]')
    const input = this.courseItemWrapperTarget.querySelector(".dropdown-input")
    if (label) label.textContent = "— select course item —"
    if (input) input.value = ""
  }

  _rebuildMenu(items) {
    const menu = this.courseItemWrapperTarget.querySelector('[data-dropdown-target="menu"]')
    if (!menu) return

    const itemClasses =
      "dropdown-item block w-full px-4 py-2 text-left text-sm text-zinc-200 transition hover:bg-zinc-800/60"

    const wrapper = document.createElement("div")
    wrapper.className = "py-1"

    items.forEach((item) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = itemClasses
      btn.dataset.action = "click->dropdown#select"
      btn.dataset.dropdownLabelParam = item.label
      btn.dataset.dropdownValueParam = item.value
      btn.textContent = item.label
      wrapper.appendChild(btn)
    })

    menu.innerHTML = ""
    menu.appendChild(wrapper)
  }
}
