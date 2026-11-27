import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["description", "count", "price", "preview"]

  connect() {
    this.updateCount()
    this.updatePrice()
  }

  updateCount() {
    this.countTarget.textContent = this.descriptionTarget.value.length + " / 1000"
  }

  updatePrice() {
    const amount = Number(this.priceTarget.value)
    this.previewTarget.textContent = Number.isFinite(amount) && amount > 0
      ? new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(amount)
      : "—"
  }
}
