import { LightningElement, api, track } from 'lwc';

export default class CustomFieldRenderer extends LightningElement {
    @api field;
    @api value;
    @api required = false;
    @api error;
    @api disabled = false;

    get isText() {
        const t = this._type;
        return t === 'STRING' || t === 'TEXTAREA' || t === 'URL' || t === 'EMAIL' || t === 'PHONE';
    }
    get isPicklist() { return this._type === 'PICKLIST'; }
    get isMultiPicklist() { return this._type === 'MULTIPICKLIST'; }
    get isBoolean() { return this._type === 'BOOLEAN'; }
    get isDate() { return this._type === 'DATE'; }
    get isDateTime() { return this._type === 'DATETIME'; }
    get isNumber() {
        const t = this._type;
        return t === 'INTEGER' || t === 'DOUBLE' || t === 'CURRENCY' || t === 'PERCENT' || t === 'LONG';
    }
    get isReference() { return this._type === 'REFERENCE'; }

    get _type() {
        return this.field?.fieldType?.toUpperCase() || 'STRING';
    }

    get fieldLabel() {
        return this.field?.labelOverride || this.field?.fieldApiName;
    }

    get stringValue() {
        return this.value != null ? String(this.value) : '';
    }

    get numberValue() {
        return this.value != null ? Number(this.value) : null;
    }

    get booleanValue() {
        return this.value === true || this.value === 'true';
    }

    get referenceObjectName() {
        return this.field?.referenceTo || 'Account';
    }

    get picklistOptions() {
        if (!this.field?.picklistPermissions?.length) return [];
        const userPerms = this._userPermissions || [];
        return this.field.picklistPermissions
            .filter(p => !p.customPermissionApiName || userPerms.includes(p.customPermissionApiName))
            .map(p => ({ label: p.picklistValue, value: p.picklistValue }));
    }

    @api userPermissions = [];

    get _userPermissions() {
        return this.userPermissions || [];
    }

    get formatter() {
        const t = this._type;
        if (t === 'CURRENCY') return 'currency';
        if (t === 'PERCENT') return 'percent-fixed';
        return 'decimal';
    }

    get inputType() {
        const t = this._type;
        if (t === 'EMAIL') return 'email';
        if (t === 'URL') return 'url';
        if (t === 'PHONE') return 'tel';
        if (t === 'TEXTAREA') return 'text';
        return 'text';
    }

    get isTextArea() {
        return this._type === 'TEXTAREA';
    }

    handleTextChange(event) {
        this._dispatch(event.target.value);
    }

    handleNumberChange(event) {
        this._dispatch(event.target.value !== '' ? Number(event.target.value) : null);
    }

    handleBooleanChange(event) {
        this._dispatch(event.target.checked);
    }

    handleDateChange(event) {
        this._dispatch(event.target.value);
    }

    handlePicklistChange(event) {
        this._dispatch(event.detail.value);
    }

    handleReferenceChange(event) {
        this._dispatch(event.detail.recordId);
    }

    _dispatch(val) {
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { fieldApiName: this.field?.fieldApiName, value: val },
            bubbles: false
        }));
    }
}
