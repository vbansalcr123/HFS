import { LightningElement, api } from "lwc";
import { labels } from "./hfs_trainingCourseGridUtils";

/**
 * Presentational child that renders the responsive course grid. Shows the empty state when the
 * filtered list is empty (AC2 edge / AC4).
 *
 * HFS-34: passes per-card busy-action and retry-message state down to each card so the container
 * can drive the in-flight / fail-closed UI. The `courseaction` event from a card bubbles straight
 * through this grid to the container (bubbles + composed) - no re-dispatch needed here.
 */
export default class HfsTrainingCourseGrid extends LightningElement {
  _courses = [];
  _busyByCourseId = {};
  _retryByCourseId = {};

  labels = labels;

  @api
  get courses() {
    return this._courses;
  }
  set courses(value) {
    this._courses = value || [];
  }

  // Map of courseId -> in-flight action verb, set by the container.
  @api
  get busyByCourseId() {
    return this._busyByCourseId;
  }
  set busyByCourseId(value) {
    this._busyByCourseId = value || {};
  }

  // Map of courseId -> retry message, set by the container on a fail-closed action.
  @api
  get retryByCourseId() {
    return this._retryByCourseId;
  }
  set retryByCourseId(value) {
    this._retryByCourseId = value || {};
  }

  get hasCourses() {
    return this._courses.length > 0;
  }

  // Merge each card's live busy/retry state into a view model without mutating the source list.
  get displayCourses() {
    return this._courses.map((course) => ({
      course,
      busyAction: this._busyByCourseId[course.id],
      retryMessage: this._retryByCourseId[course.id]
    }));
  }
}
