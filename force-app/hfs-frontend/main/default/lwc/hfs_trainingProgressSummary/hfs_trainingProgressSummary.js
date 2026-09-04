import { LightningElement, api } from "lwc";
import { labels, formatRemaining } from "./hfs_trainingProgressSummaryUtils";

/**
 * Presentational child that renders the dark learning-progress panel: percent bar, the
 * "X% — N of M complete · R remaining · Est. Hh Mm" line, and the View Certificates /
 * Resume Last Course actions. Shows the first-time state when the user has no progress.
 */
export default class HfsTrainingProgressSummary extends LightningElement {
  @api summary;

  labels = labels;

  get hasProgress() {
    return this.summary && this.summary.hasProgress;
  }

  get percentComplete() {
    return (this.summary && this.summary.percentComplete) || 0;
  }

  get progressStyle() {
    return `width: ${this.percentComplete}%;`;
  }

  get progressLine() {
    if (!this.summary) {
      return "";
    }
    const completed = this.summary.coursesCompleted || 0;
    const total = this.summary.coursesTotal || 0;
    const remaining = this.summary.coursesRemaining || 0;
    const est = formatRemaining(this.summary.estRemainingMinutes);
    return `${this.percentComplete}% — ${completed} of ${total} courses complete · ${remaining} remaining · Est. ${est}`;
  }

  get canResume() {
    return this.summary && this.summary.resumeCourseId;
  }

  // Actions emit events only; the action behaviour (open/navigate) is HFS-34.
  handleViewCertificates() {
    this.dispatchEvent(new CustomEvent("viewcertificates"));
  }

  handleResume() {
    this.dispatchEvent(
      new CustomEvent("resumecourse", {
        detail: { courseId: this.summary.resumeCourseId }
      })
    );
  }
}
