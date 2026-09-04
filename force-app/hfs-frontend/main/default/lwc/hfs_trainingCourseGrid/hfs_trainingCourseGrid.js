import { LightningElement, api } from "lwc";
import { labels } from "./hfs_trainingCourseGridUtils";

/**
 * Presentational child that renders the responsive course grid. Shows the empty state when the
 * filtered list is empty (AC2 edge / AC4).
 */
export default class HfsTrainingCourseGrid extends LightningElement {
  _courses = [];

  labels = labels;

  @api
  get courses() {
    return this._courses;
  }
  set courses(value) {
    this._courses = value || [];
  }

  get hasCourses() {
    return this._courses.length > 0;
  }
}
