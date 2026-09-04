/**
 * @description Centralizes common null / blank / empty guard checks so each
 * Controller boundary does not hand-write its own. Throws hfs_ApplicationException with
 * a technical code from hfs_Constants on failure.
 */
public class hfs_Guard {
    /**
     * @description Ensures a value is not null.
     * @param value the value to check
     * @param fieldName developer-facing name of the checked argument
     */
    public static void notNull(Object value, String fieldName) {
        if (value == null) {
            throw hfs_ApplicationException.build(
                'Argument [' + fieldName + '] must not be null.',
                hfs_Constants.NULL_ARGUMENT
            );
        }
    }

    /**
     * @description Ensures a String is not blank.
     * @param value the value to check
     * @param fieldName developer-facing name of the checked argument
     */
    public static void notBlank(String value, String fieldName) {
        if (String.isBlank(value)) {
            throw hfs_ApplicationException.build(
                'Argument [' + fieldName + '] must not be blank.',
                hfs_Constants.EMPTY_PAYLOAD
            );
        }
    }
}