import PROGRESS_HEADING from "@salesforce/label/c.hfs_Training_ProgressHeading";
import VIEW_CERTIFICATES from "@salesforce/label/c.hfs_Training_ViewCertificates";
import RESUME_LAST_COURSE from "@salesforce/label/c.hfs_Training_ResumeLastCourse";
import FIRST_TIME_MESSAGE from "@salesforce/label/c.hfs_Training_FirstTimeMessage";

// Colocated labels for the hfs_trainingProgressSummary bundle.
export const labels = {
  heading: PROGRESS_HEADING,
  viewCertificates: VIEW_CERTIFICATES,
  resumeLastCourse: RESUME_LAST_COURSE,
  firstTime: FIRST_TIME_MESSAGE
};

/**
 * Formats a minutes total as "Xh Ym" (e.g. 270 -> "4h 30m").
 * @param {number} totalMinutes minutes remaining
 * @returns {string} the formatted duration
 */
export function formatRemaining(totalMinutes) {
  const minutes = Number(totalMinutes) || 0;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  if (hours > 0) {
    return `${hours}h ${mins}m`;
  }
  return `${mins}m`;
}
