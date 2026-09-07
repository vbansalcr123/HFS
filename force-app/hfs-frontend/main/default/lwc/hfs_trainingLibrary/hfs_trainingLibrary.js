import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getTraining from "@salesforce/apex/hfs_TrainingController.getTraining";
import startCourse from "@salesforce/apex/hfs_TrainingController.startCourse";
import resumeCourse from "@salesforce/apex/hfs_TrainingController.resumeCourse";
import completeCourse from "@salesforce/apex/hfs_TrainingController.completeCourse";
import retakeCourse from "@salesforce/apex/hfs_TrainingController.retakeCourse";
import getCertificate from "@salesforce/apex/hfs_TrainingController.getCertificate";
import {
  labels,
  CATEGORIES,
  ALL_COURSES_KEY,
  ACTION,
  CONTENT_UNAVAILABLE
} from "./hfs_trainingLibraryUtils";

/**
 * Parent container for the Training Library page. The single smart component: owns the one
 * cacheable @wire read, holds the selected category in state, orchestrates loading / loaded /
 * empty / unavailable states, and renders the three child section components.
 *
 * HFS-34: also owns the imperative write actions. On a `courseaction` event from a card it sets a
 * per-course busy flag, calls the matching Controller action, checks data.isSuccess (never assumes
 * success from a resolved Promise), opens the returned content / certificate URL, then refreshApex
 * so the card status and the progress summary reconcile. On CONTENT_UNAVAILABLE it surfaces the
 * retry message on that card without advancing status. A second click during an in-flight action
 * is ignored (double-trigger protection).
 */
export default class HfsTrainingLibrary extends LightningElement {
  labels = labels;

  isLoading = true;
  isUnavailable = false;
  summary;
  allCourses = [];
  selectedCategory = ALL_COURSES_KEY;

  // Per-course action state driving the cards' busy / retry UI.
  busyByCourseId = {};
  retryByCourseId = {};

  // Cached wired result so refreshApex can re-run the read after a successful write.
  wiredResult;

  // Maps action verbs to the imperative Apex functions.
  actionHandlers = {
    [ACTION.START]: startCourse,
    [ACTION.RESUME]: resumeCourse,
    [ACTION.COMPLETE]: completeCourse,
    [ACTION.RETAKE]: retakeCourse,
    [ACTION.VIEW_CERTIFICATE]: getCertificate
  };

  @wire(getTraining)
  wiredTraining(result) {
    this.wiredResult = result;
    const { error, data } = result;
    this.isLoading = false;
    // hfs_Response resolves into the data branch even on business failure - check isSuccess.
    if (data && data.isSuccess) {
      this.isUnavailable = false;
      this.summary = data.payload ? data.payload.summary : undefined;
      this.allCourses = (data.payload && data.payload.courses) || [];
    } else if (error || (data && !data.isSuccess)) {
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

  // Imperative write path for the card actions (Start / Resume / Complete / Retake / Certificate).
  async handleCourseAction(event) {
    const { courseId, action } = event.detail;
    const handler = this.actionHandlers[action];
    if (!courseId || !handler || this.busyByCourseId[courseId]) {
      // Ignore unknown actions and repeat clicks during an in-flight action.
      return;
    }

    this.setBusy(courseId, action);
    this.clearRetry(courseId);

    try {
      const response = await handler({ courseId });
      // Never assume success from a resolved Promise - branch on hfs_Response.isSuccess.
      if (response && response.isSuccess) {
        this.openActionTarget(response.payload);
        await refreshApex(this.wiredResult);
      } else if (response && response.errorCode === CONTENT_UNAVAILABLE) {
        // Fail-closed: show retry on the card, do not advance status.
        this.setRetry(courseId, labels.retryContentUnavailable);
      } else {
        this.setRetry(
          courseId,
          (response && response.errorMessage) || labels.actionFailed
        );
      }
    } catch {
      this.setRetry(courseId, labels.actionFailed);
    } finally {
      this.clearBusy(courseId);
    }
  }

  // Open the content or certificate URL returned by the action, if any.
  openActionTarget(payload) {
    if (!payload) {
      return;
    }
    const target = payload.contentUrl || payload.certificateUrl;
    if (target) {
      window.open(target, "_blank", "noopener");
    }
  }

  setBusy(courseId, action) {
    this.busyByCourseId = { ...this.busyByCourseId, [courseId]: action };
  }

  clearBusy(courseId) {
    const next = { ...this.busyByCourseId };
    delete next[courseId];
    this.busyByCourseId = next;
  }

  setRetry(courseId, message) {
    this.retryByCourseId = { ...this.retryByCourseId, [courseId]: message };
  }

  clearRetry(courseId) {
    const next = { ...this.retryByCourseId };
    delete next[courseId];
    this.retryByCourseId = next;
  }
}
