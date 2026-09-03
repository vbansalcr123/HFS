import { LightningElement, api } from "lwc";
import { labels, STATUS, formatDate } from "./hfs_trainingCourseCardUtils";

/**
 * Presentational course card. Shows category, title, status chip, description, duration, module
 * count, due date (overdue vs upcoming styling), new-release flag, a per-card progress bar and
 * current module for in-progress courses, and completion date for completed courses. Status is
 * announced to assistive tech and the card is keyboard-reachable (WCAG 2.1 AA).
 */
export default class HfsTrainingCourseCard extends LightningElement {
  @api course;

  labels = labels;

  get isCompleted() {
    return this.course && this.course.status === STATUS.COMPLETED;
  }

  get isInProgress() {
    return this.course && this.course.status === STATUS.IN_PROGRESS;
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
}
