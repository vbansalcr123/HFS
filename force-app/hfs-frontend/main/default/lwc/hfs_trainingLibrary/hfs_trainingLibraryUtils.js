import PAGE_TITLE from "@salesforce/label/c.hfs_Training_PageTitle";
import SUBTITLE from "@salesforce/label/c.hfs_Training_Subtitle";
import ALL_COURSES from "@salesforce/label/c.hfs_Training_AllCourses";
import LOADING_MESSAGE from "@salesforce/label/c.hfs_Training_LoadingMessage";
import UNAVAILABLE_MESSAGE from "@salesforce/label/c.hfs_Training_UnavailableMessage";

// Colocated labels + constants for the hfs_trainingLibrary bundle.
export const labels = {
  pageTitle: PAGE_TITLE,
  subtitle: SUBTITLE,
  allCourses: ALL_COURSES,
  loading: LOADING_MESSAGE,
  unavailable: UNAVAILABLE_MESSAGE
};

// The picklist categories, in display order. "All Courses" is a UI-only filter.
export const CATEGORIES = [
  "Onboarding",
  "Brand & Standards",
  "Payment & Loyalty",
  "Site Operations",
  "Fuel & Products",
  "Compliance"
];

export const ALL_COURSES_KEY = ALL_COURSES;
