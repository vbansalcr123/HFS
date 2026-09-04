import { LightningElement, wire } from "lwc";
import getTraining from "@salesforce/apex/hfs_TrainingController.getTraining";
import {
  labels,
  CATEGORIES,
  ALL_COURSES_KEY
} from "./hfs_trainingLibraryUtils";

/**
 * Parent container for the Training Library page. The single smart component: owns the one
 * cacheable @wire read, holds the selected category in state, orchestrates loading / loaded /
 * empty / unavailable states, and renders the three child section components.
 */
export default class HfsTrainingLibrary extends LightningElement {
  labels = labels;

  isLoading = true;
  isUnavailable = false;
  summary;
  allCourses = [];
  selectedCategory = ALL_COURSES_KEY;

  @wire(getTraining)
  wiredTraining({ error, data }) {
    this.isLoading = false;
    console.log(error, data);
    // hfs_Response resolves into the data branch even on business failure — check isSuccess.
    if (data && data.isSuccess) {
      this.isUnavailable = false;
      this.summary = data.payload ? data.payload.summary : undefined;
      this.allCourses = (data.payload && data.payload.courses) || [];
    } else {
      this.isUnavailable = true;
      this.summary = undefined;
      this.allCourses = [];
    }
  }

  get categories() {
    return CATEGORIES;
  }

  get hasData() {
    return !this.isLoading && !this.isUnavailable;
  }

  // Filter the already-scoped card list in memory; no re-query on chip clicks.
  get filteredCourses() {
    if (this.selectedCategory === ALL_COURSES_KEY) {
      return this.allCourses;
    }
    return this.allCourses.filter(
      (course) => course.category === this.selectedCategory
    );
  }

  handleCategoryChange(event) {
    this.selectedCategory = event.detail.category;
    // Reset the view to the top on a filter change.
    const grid = this.template.querySelector("c-hfs_training-course-grid");
    if (grid) {
      grid.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }
}
