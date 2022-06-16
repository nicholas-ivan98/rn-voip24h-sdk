export default class OAuth {
    constructor(token, createAt, expired, isLongAlive) {
        this.token = token;
        this.createAt = createAt;
        this.expired = expired;
        this.isLongAlive = isLongAlive;
    }
}