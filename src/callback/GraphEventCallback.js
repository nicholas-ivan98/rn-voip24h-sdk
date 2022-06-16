export interface AccessTokenEventCallback {
    success: (statusCode, message, oauth) => void;
    error: (statusCode, message) => void;
}

export interface RequestEventCallback {
    success: (statusCode, message, jsonObject: object) => void;
    error: (statusCode, message) => void;
}