import STATUS_COMPLETED from "@salesforce/label/c.hfs_Training_StatusCompleted";
import STATUS_IN_PROGRESS from "@salesforce/label/c.hfs_Training_StatusInProgress";
import STATUS_NOT_STARTED from "@salesforce/label/c.hfs_Training_StatusNotStarted";
import NEW_BADGE from "@salesforce/label/c.hfs_Training_NewBadge";
import ACTION_START from "@salesforce/label/c.hfs_Training_Action_Start";
import ACTION_RESUME from "@salesforce/label/c.hfs_Training_Action_Resume";
import ACTION_RETAKE from "@salesforce/label/c.hfs_Training_Action_Retake";
import ACTION_VIEW_CERTIFICATE from "@salesforce/label/c.hfs_Training_Action_ViewCertificate";
import BUSY from "@salesforce/label/c.hfs_Training_Busy";
import RETRY_CONTENT_UNAVAILABLE from "@salesforce/label/c.hfs_Training_Retry_ContentUnavailable";

// Colocated labels for the hfs_trainingCourseCard bundle.
export const labels = {
  completed: STATUS_COMPLETED,
  inProgress: STATUS_IN_PROGRESS,
  notStarted: STATUS_NOT_STARTED,
  newBadge: NEW_BADGE,
  actionStart: ACTION_START,
  actionResume: ACTION_RESUME,
  actionRetake: ACTION_RETAKE,
  actionViewCertificate: ACTION_VIEW_CERTIFICATE,
  busy: BUSY,
  retryContentUnavailable: RETRY_CONTENT_UNAVAILABLE
};

export const STATUS = {
  COMPLETED: "Completed",
  IN_PROGRESS: "In Progress",
  NOT_STARTED: "Not Started"
};

// Action verbs emitted on the courseaction event; the container maps these to Apex calls.
export const ACTION = {
  START: "start",
  RESUME: "resume",
  COMPLETE: "complete",
  RETAKE: "retake",
  VIEW_CERTIFICATE: "viewCertificate"
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
