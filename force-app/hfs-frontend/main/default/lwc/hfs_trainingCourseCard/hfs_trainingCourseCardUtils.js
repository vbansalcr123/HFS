import STATUS_COMPLETED from "@salesforce/label/c.hfs_Training_StatusCompleted";
import STATUS_IN_PROGRESS from "@salesforce/label/c.hfs_Training_StatusInProgress";
import STATUS_NOT_STARTED from "@salesforce/label/c.hfs_Training_StatusNotStarted";
import NEW_BADGE from "@salesforce/label/c.hfs_Training_NewBadge";

// Colocated labels for the hfs_trainingCourseCard bundle.
export const labels = {
  completed: STATUS_COMPLETED,
  inProgress: STATUS_IN_PROGRESS,
  notStarted: STATUS_NOT_STARTED,
  newBadge: NEW_BADGE
};

export const STATUS = {
  COMPLETED: "Completed",
  IN_PROGRESS: "In Progress",
  NOT_STARTED: "Not Started"
};

/**
 * Formats an ISO date (yyyy-mm-dd) into a readable "Month D, YYYY".
 * @param {string} value the ISO date
 * @returns {string} the formatted date, or '' when absent
 */
export function formatDate(value) {
  if (!value) {
    return "";
  }
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric"
  });
}
