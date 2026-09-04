import GENERIC_ERROR from '@salesforce/label/c.hfs_Msg_Generic_Error';

/**
 * Parses an hfs_Response returned by an Apex Controller. Every Controller
 * method returns { isSuccess, payload, errorMessage, errorCode } — always
 * branch on isSuccess, never assume success just because the Promise resolved.
 *
 * @param {object} response the hfs_Response payload from an Apex call
 * @returns {{ ok: boolean, payload: object, message: string, code: string }}
 */
export function parseResponse(response) {
    if (response && response.isSuccess === true) {
        return { ok: true, payload: response.payload, message: '', code: '' };
    }
    const message =
        response && response.errorMessage ? response.errorMessage : GENERIC_ERROR;
    const code = response && response.errorCode ? response.errorCode : 'UNEXPECTED';
    return { ok: false, payload: null, message, code };
}

/**
 * Extracts a safe, displayable message from a thrown/rejected Apex error.
 *
 * @param {*} error the rejected error object
 * @returns {string} a safe error message
 */
export function reduceError(error) {
    if (!error) {
        return GENERIC_ERROR;
    }
    if (error.body && error.body.message) {
        return error.body.message;
    }
    if (typeof error.message === 'string') {
        return error.message;
    }
    return GENERIC_ERROR;
}