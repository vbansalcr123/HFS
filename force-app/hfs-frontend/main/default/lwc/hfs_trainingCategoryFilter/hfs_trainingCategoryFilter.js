import { LightningElement, api } from "lwc";
import { labels, CATEGORY_ICONS } from "./hfs_trainingCategoryFilterUtils";

/**
 * Presentational child that renders the category filter chips (All Courses + the picklist
 * categories) and emits the selected category. Chips are keyboard-operable with aria-pressed
 * on the active chip (WCAG 2.1 AA).
 */
export default class HfsTrainingCategoryFilter extends LightningElement {
  _categories = [];

  @api selected;

  @api
  get categories() {
    return this._categories;
  }
  set categories(value) {
    this._categories = value || [];
  }

  get chips() {
    const all = {
      key: labels.allCourses,
      value: labels.allCourses,
      label: labels.allCourses,
      isActive: this.selected === labels.allCourses,
      cssClass: this.chipClass(this.selected === labels.allCourses)
    };
    const rest = this._categories.map((category) => {
      const icon = CATEGORY_ICONS[category] || "";
      const isActive = this.selected === category;
      return {
        key: category,
        value: category,
        label: icon ? `${icon} ${category}` : category,
        isActive,
        cssClass: this.chipClass(isActive)
      };
    });
    return [all, ...rest];
  }

  chipClass(isActive) {
    return isActive ? "hfs-chip hfs-chip_active" : "hfs-chip";
  }

  handleSelect(event) {
    const category = event.currentTarget.dataset.value;
    this.dispatchEvent(
      new CustomEvent("categorychange", { detail: { category } })
    );
  }
}
