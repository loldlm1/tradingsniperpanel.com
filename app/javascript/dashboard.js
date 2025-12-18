import { Turbo } from "@hotwired/turbo-rails"

function bindLightSwitches() {
  document.querySelectorAll(".light-switch").forEach((lightSwitch, index) => {
    if (lightSwitch.dataset.bound === "true") return
    lightSwitch.dataset.bound = "true"

    if (localStorage.getItem("dark-mode") === "true") {
      lightSwitch.checked = true
    }

    lightSwitch.addEventListener("change", () => {
      const { checked } = lightSwitch
      document.querySelectorAll(".light-switch").forEach((el, n) => {
        if (n !== index) el.checked = checked
      })
      document.documentElement.classList.add("**:transition-none!")
      if (checked) {
        document.documentElement.classList.add("dark")
        document.querySelector("html").style.colorScheme = "dark"
        localStorage.setItem("dark-mode", true)
      } else {
        document.documentElement.classList.remove("dark")
        document.querySelector("html").style.colorScheme = "light"
        localStorage.setItem("dark-mode", false)
      }
      setTimeout(() => document.documentElement.classList.remove("**:transition-none!"), 1)
    })
  })
}

function initAlpine() {
  if (window.Alpine) {
    if (!window.AlpineStarted && window.Alpine.start) {
      window.Alpine.start()
      window.AlpineStarted = true
    } else if (window.Alpine.initTree) {
      window.Alpine.initTree(document.body)
    }
  }
}

document.addEventListener("turbo:load", () => {
  initAlpine()
  bindLightSwitches()
})

document.addEventListener("turbo:before-cache", () => {
  if (window.Alpine && window.Alpine.destroyTree) {
    window.Alpine.destroyTree(document.body)
    window.AlpineStarted = false
  }
  document.querySelectorAll(".light-switch").forEach((el) => {
    el.dataset.bound = "false"
  })
})

// Run once on initial load (non-Turbo navigation)
if (!Turbo.navigator.started) {
  initAlpine()
  bindLightSwitches()
}
