import { LightningElement, api } from "lwc";
import {
  labels,
  STATUS,
  ACTION,
  formatDate
} from "./hfs_trainingCourseCardUtils";

/**
 * Presentational course card. Shows category, title, status chip, description, duration, module
 * count, due date (overdue vs upcoming styling), new-release flag, a per-card progress bar and
 * current module for in-progress courses, and completion date for completed courses.
 *
 * HFS-34: renders status-appropriate action buttons (Start / Resume / View Certificate + Retake),
 * shows a per-action busy state (double-trigger disabled), surfaces a retry message when the
 * container reports content is unavailable, and emits a `courseaction` event upward. The card
 * stays dumb - it never calls Apex; the smart container performs the write. All actions are
 * keyboard-reachable with clear labelled states (WCAG 2.1 AA).
 */
export default class HfsTrainingCourseCard extends LightningElement {
  @api course;

  // Which action (if any) is in-flight, driving the disabled / spinner state on this card.
  @api busyAction;

  // A retry message set by the container when an action fails closed (content unavailable).
  @api retryMessage;

  labels = labels;

  get isCompleted() {
    return this.course && this.course.status === STATUS.COMPLETED;
  }

  get isInProgress() {
    return this.course && this.course.status === STATUS.IN_PROGRESS;
  }

  get isNotStarted() {
    return !this.isCompleted && !this.isInProgress;
  }

  // Any in-flight action disables all of this card's action buttons (double-trigger protection).
  get isBusy() {
    return !!this.busyAction;
  }

  get statusLabel() {
    if (!this.course) {
      return "";
    }
    switch (this.course.status) {
      case STATUS.COMPLETED:
        return labels.completed;
      case STATUS.IN_PROGRESS:
        return labels.inProgress;
      default:
        return labels.notStarted;
    }
  }

  get statusChipClass() {
    const base = "hfs-status-chip";
    if (this.isCompleted) {
      return `${base} hfs-status-chip_completed`;
    }
    if (this.isInProgress) {
      return `${base} hfs-status-chip_inprogress`;
    }
    return `${base} hfs-status-chip_notstarted`;
  }

  get cardClass() {
    return this.isCompleted
      ? "hfs-card hfs-card_completed"
      : this.isInProgress
        ? "hfs-card hfs-card_inprogress"
        : "hfs-card";
  }

  get metaLine() {
    if (!this.course) {
      return "";
    }
    const parts = [];
    if (this.course.durationMinutes) {
      parts.push(`${this.course.durationMinutes} min`);
    }
    if (this.course.moduleCount) {
      parts.push(`${this.course.moduleCount} modules`);
    }
    return parts.join(" | ");
  }

  get progressStyle() {
    const percent = (this.course && this.course.percentComplete) || 0;
    return `width: ${percent}%;`;
  }

  get moduleLine() {
    if (
      !this.course ||
      !this.course.currentModule ||
      !this.course.moduleCount
    ) {
      return "";
    }
    return `Module ${this.course.currentModule} of ${this.course.moduleCount}`;
  }

  get completionLine() {
    const formatted = formatDate(this.course && this.course.completionDate);
    return formatted ? `Completed: ${formatted}` : "";
  }

  get dueLine() {
    const formatted = formatDate(this.course && this.course.dueDate);
    if (!formatted) {
      return "";
    }
    return this.course.isOverdue
      ? `Overdue: ${formatted}`
      : `Due: ${formatted}`;
  }

  get dueClass() {
    return this.course && this.course.isOverdue
      ? "hfs-due hfs-due_overdue"
      : "hfs-due";
  }

  get ariaLabel() {
    return `${this.course ? this.course.title : ""}, ${this.statusLabel}`;
  }

  // Per-button busy flags so only the clicked action shows a spinner while all are disabled.
  get isStartBusy() {
    return this.busyAction === ACTION.START;
  }

  get isResumeBusy() {
    return this.busyAction === ACTION.RESUME;
  }

  get isRetakeBusy() {
    return this.busyAction === ACTION.RETAKE;
  }

  get isViewCertificateBusy() {
    return this.busyAction === ACTION.VIEW_CERTIFICATE;
  }

  handleStart() {
    this.emitAction(ACTION.START);
  }

  handleResume() {
    this.emitAction(ACTION.RESUME);
  }

  handleRetake() {
    this.emitAction(ACTION.RETAKE);
  }

  handleViewCertificate() {
    this.emitAction(ACTION.VIEW_CERTIFICATE);
  }

  // Ignore repeat clicks while an action is in flight, then bubble the request to the container.
  emitAction(action) {
    if (this.isBusy || !this.course) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("courseaction", {
        detail: { courseId: this.course.id, action },
        bubbles: true,
        composed: true
      })
    );
  }
}
