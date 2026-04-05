import { LightningElement, api, track } from 'lwc';

const SPLIT_STANDARD = ['LAST_SPACE', 'FIRST_SPACE', 'ALL_PRIMARY', 'ALL_SECONDARY'];

export default class CustomFieldRenderer extends LightningElement {
    @api field;
    @api value;
    @api secondaryValue;
    @api required = false;
    @api error;
    @api disabled = false;

    @track _resolvedReferenceValue = null;

    connectedCallback() {
        Promise.resolve().then(() => {
            this._resolvedReferenceValue = this.value || null;
        });
    }

    get isGroupedPrimary() {
        return !!(this.field?.groupWith && this.field?.groupPrimary);
    }

    get isText() {
        if (this.isGroupedPrimary) return false;
        const t = this._type;
        return t === 'STRING' || t === 'TEXTAREA' || t === 'URL' || t === 'EMAIL' || t === 'PHONE';
    }
    get isPicklist() { return !this.isGroupedPrimary && this._type === 'PICKLIST'; }
    get isMultiPicklist() { return !this.isGroupedPrimary && this._type === 'MULTIPICKLIST'; }
    get isBoolean() { return !this.isGroupedPrimary && this._type === 'BOOLEAN'; }
    get isDate() { return !this.isGroupedPrimary && this._type === 'DATE'; }
    get isDateTime() { return !this.isGroupedPrimary && this._type === 'DATETIME'; }
    get isNumber() {
        if (this.isGroupedPrimary) return false;
        const t = this._type;
        return t === 'INTEGER' || t === 'DOUBLE' || t === 'CURRENCY' || t === 'PERCENT' || t === 'LONG';
    }
    get isReference() { return !this.isGroupedPrimary && this._type === 'REFERENCE'; }

    get _type() {
        return this.field?.fieldType?.toUpperCase() || 'STRING';
    }

    get fieldLabel() {
        if (this.field?.groupWith && this.field?.groupPrimary) {
            return this.field?.groupLabel || this.field?.labelOverride || this.field?.fieldLabel || this.field?.fieldApiName;
        }
        return this.field?.labelOverride || this.field?.fieldLabel || this.field?.fieldApiName;
    }

    get helpText() {
        return this.field?.helpText || null;
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

    get referenceValue() {
        return this._resolvedReferenceValue || this.value || null;
    }

    get picklistOptions() {
        const allValues = (this.field?.picklistValues || []).map(pv => ({ label: pv.label, value: pv.value }));
        const perms = this.field?.picklistPermissions || [];

        if (!perms.length) return allValues;

        const userPerms = this._userPermissions || [];
        const filtered = perms
            .filter(p => !p.customPermissionApiName || userPerms.includes(p.customPermissionApiName))
            .map(p => ({ label: p.picklistValue, value: p.picklistValue }));

        return filtered.length ? filtered : allValues;
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

    // --- Grouped field helpers ---

    get groupedDisplayValue() {
        const secondary = this.secondaryValue != null ? String(this.secondaryValue) : '';
        const primary = this.value != null ? String(this.value) : '';
        if (!secondary && !primary) return '';
        if (!secondary) return primary;
        return secondary + ' ' + primary;
    }

    get groupedLabel() {
        return this.field?.groupLabel || this.fieldLabel;
    }

    _splitByPattern(combined, pattern) {
        if (!combined) return { primary: '', secondary: '' };
        if (pattern === 'ALL_PRIMARY') return { primary: combined, secondary: '' };
        if (pattern === 'ALL_SECONDARY') return { primary: '', secondary: combined };

        let idx = -1;
        let delimLen = 1;

        if (pattern === 'LAST_SPACE' || !pattern) {
            idx = combined.lastIndexOf(' ');
        } else if (pattern === 'FIRST_SPACE') {
            idx = combined.indexOf(' ');
        } else {
            // Custom delimiter
            idx = combined.indexOf(pattern);
            delimLen = pattern.length;
        }

        if (idx === -1) return { primary: combined, secondary: '' };
        return {
            secondary: combined.substring(0, idx),
            primary: combined.substring(idx + delimLen)
        };
    }

    _enforceGroupPrimary(result, combined) {
        if (combined && !result.primary) {
            return { primary: combined, secondary: '' };
        }
        return result;
    }

    get splitHint() {
        if (!this.isGroupedPrimary) return null;
        const combined = this.groupedDisplayValue;
        if (!combined) return null;
        const pattern = this.field?.splitPattern || 'LAST_SPACE';
        const result = this._splitByPattern(combined, pattern);
        if (!result.secondary) return 'No delimiter found — all text will go to primary field';
        return null;
    }

    get splitPreview() {
        if (!this.isGroupedPrimary) return null;
        const combined = this.groupedDisplayValue;
        if (!combined) return null;
        const pattern = this.field?.splitPattern || 'LAST_SPACE';
        const result = this._splitByPattern(combined, pattern);
        if (!result.secondary) return null;
        return `Secondary: "${result.secondary}" — Primary: "${result.primary}"`;
    }

    // --- Event handlers ---

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

    handleGroupedChange(event) {
        const combined = event.target.value || '';
        const pattern = this.field?.splitPattern || 'LAST_SPACE';
        const raw = this._splitByPattern(combined, pattern);
        const result = this._enforceGroupPrimary(raw, combined);

        // Dispatch primary
        this._dispatch(result.primary);
        // Dispatch secondary to the grouped field
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { fieldApiName: this.field?.groupWith, value: result.secondary },
            bubbles: false
        }));
    }

    _dispatch(val) {
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { fieldApiName: this.field?.fieldApiName, value: val },
            bubbles: false
        }));
    }
}
