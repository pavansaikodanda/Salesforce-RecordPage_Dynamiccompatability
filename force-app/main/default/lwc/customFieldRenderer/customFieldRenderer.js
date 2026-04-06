import { LightningElement, api, track } from 'lwc';

export default class CustomFieldRenderer extends LightningElement {
    @api field;
    @api value;
    @api secondaryValue;
    @api required = false;
    @api disabled = false;
    @api userPermissions = [];

    @track _resolvedReferenceValue = null;

    _error = null;

    // error as getter/setter so setting it from the parent immediately applies
    // native validity to whichever input is currently rendered.
    @api
    get error() {
        return this._error;
    }
    set error(val) {
        this._error = val || null;
        this._applyError();
    }

    connectedCallback() {
        Promise.resolve().then(() => {
            this._resolvedReferenceValue = this.value || null;
        });
    }

    renderedCallback() {
        // Re-apply after each render in case the input was swapped out.
        if (this._error) {
            this._applyError();
        }
    }

    _applyError() {
        const input = this.template.querySelector(
            'lightning-input, lightning-textarea, lightning-combobox, lightning-dual-listbox'
        );
        if (!input || typeof input.setCustomValidity !== 'function') return;
        input.setCustomValidity(this._error || '');
        input.reportValidity();
    }

    // Validates regex on blur and applies/clears native validity inline.
    handleBlur(event) {
        const pattern = this.field?.regexPattern;
        if (!pattern) {
            // Clear any stale regex error but leave required errors alone.
            if (this._error && this._error !== (this.field?.regexErrorMessage || '')) {
                this._applyError();
            }
            return;
        }
        const val = event.target.value != null ? String(event.target.value) : '';
        if (!val) {
            this._applyError(); // keep whatever the parent set; don't add a new one
            return;
        }
        try {
            const regex = new RegExp(pattern);
            const msg = regex.test(val) ? '' : (this.field.regexErrorMessage || 'Invalid format');
            this._error = msg || null;
            this._applyError();
        } catch (e) {
            // Malformed regex — skip client-side validation
        }
    }

    // --- Type helpers ---

    get isGroupedPrimary() {
        return !!(this.field?.groupWith && this.field?.groupPrimary);
    }

    get isText() {
        if (this.isGroupedPrimary) return false;
        const t = this._type;
        return t === 'STRING' || t === 'TEXTAREA' || t === 'URL' || t === 'EMAIL' || t === 'PHONE';
    }
    get isPicklist()      { return !this.isGroupedPrimary && this._type === 'PICKLIST'; }
    get isMultiPicklist() { return !this.isGroupedPrimary && this._type === 'MULTIPICKLIST'; }
    get isBoolean()       { return !this.isGroupedPrimary && this._type === 'BOOLEAN'; }
    get isDate()          { return !this.isGroupedPrimary && this._type === 'DATE'; }
    get isDateTime()      { return !this.isGroupedPrimary && this._type === 'DATETIME'; }
    get isNumber() {
        if (this.isGroupedPrimary) return false;
        const t = this._type;
        return t === 'INTEGER' || t === 'DOUBLE' || t === 'CURRENCY' || t === 'PERCENT' || t === 'LONG';
    }
    get isReference() { return !this.isGroupedPrimary && this._type === 'REFERENCE'; }
    get isTextArea()   { return this._type === 'TEXTAREA'; }

    get _type() {
        return this.field?.fieldType?.toUpperCase() || 'STRING';
    }

    // --- Label / display helpers ---

    get fieldLabel() {
        if (this.field?.groupWith && this.field?.groupPrimary) {
            return this.field?.groupLabel || this.field?.labelOverride || this.field?.fieldLabel || this.field?.fieldApiName;
        }
        return this.field?.labelOverride || this.field?.fieldLabel || this.field?.fieldApiName;
    }

    get helpText() {
        return this.field?.helpText || null;
    }

    // --- Value coercions ---

    get stringValue()  { return this.value != null ? String(this.value) : ''; }
    get numberValue()  { return this.value != null ? Number(this.value) : null; }
    get booleanValue() { return this.value === true || this.value === 'true'; }

    get referenceObjectName() { return this.field?.referenceTo || 'Account'; }

    get referenceValue() {
        return this._resolvedReferenceValue || this.value || null;
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
        return 'text';
    }

    // --- Picklist options ---
    // No permissions → all values.
    // Permissions present → cross-reference with allValues for correct labels,
    //   filter to values the user has permission for.
    // No values survive the filter → fall back to all values.
    get picklistOptions() {
        const allValues = (this.field?.picklistValues || []).map(pv => ({ label: pv.label, value: pv.value }));
        const perms = this.field?.picklistPermissions || [];

        if (!perms.length) return allValues;

        const userPerms = new Set(this.userPermissions || []);
        const allowedValues = new Set(
            perms
                .filter(p => p.customPermissionApiName && userPerms.has(p.customPermissionApiName))
                .map(p => p.picklistValue)
        );

        if (!allowedValues.size) return allValues;
        return allValues.filter(opt => allowedValues.has(opt.value));
    }

    // --- Grouped field helpers ---

    get groupedDisplayValue() {
        const secondary = this.secondaryValue != null ? String(this.secondaryValue) : '';
        const primary   = this.value != null ? String(this.value) : '';
        if (!secondary && !primary) return '';
        if (!secondary) return primary;
        return secondary + ' ' + primary;
    }

    _splitByPattern(combined, pattern) {
        if (!combined) return { primary: '', secondary: '' };
        if (pattern === 'ALL_PRIMARY')   return { primary: combined, secondary: '' };
        if (pattern === 'ALL_SECONDARY') return { primary: '', secondary: combined };

        let idx = -1;
        let delimLen = 1;

        if (pattern === 'LAST_SPACE' || !pattern) {
            idx = combined.lastIndexOf(' ');
        } else if (pattern === 'FIRST_SPACE') {
            idx = combined.indexOf(' ');
        } else {
            idx = combined.indexOf(pattern);
            delimLen = pattern.length;
        }

        if (idx === -1) return { primary: combined, secondary: '' };
        return {
            secondary: combined.substring(0, idx),
            primary:   combined.substring(idx + delimLen)
        };
    }

    _enforceGroupPrimary(result, combined) {
        if (combined && !result.primary) return { primary: combined, secondary: '' };
        return result;
    }

    get splitHint() {
        if (!this.isGroupedPrimary) return null;
        const combined = this.groupedDisplayValue;
        if (!combined) return null;
        const result = this._splitByPattern(combined, this.field?.splitPattern || 'LAST_SPACE');
        return result.secondary ? null : 'No delimiter found — all text will go to primary field';
    }

    get splitPreview() {
        if (!this.isGroupedPrimary) return null;
        const combined = this.groupedDisplayValue;
        if (!combined) return null;
        const result = this._splitByPattern(combined, this.field?.splitPattern || 'LAST_SPACE');
        if (!result.secondary) return null;
        return `Secondary: "${result.secondary}" — Primary: "${result.primary}"`;
    }

    // --- Event handlers ---

    handleTextChange(event)     { this._dispatch(event.target.value); }
    handleDateChange(event)     { this._dispatch(event.target.value); }
    handleBooleanChange(event)  { this._dispatch(event.target.checked); }
    handlePicklistChange(event) { this._dispatch(event.detail.value); }
    handleReferenceChange(event){ this._dispatch(event.detail.recordId); }

    handleNumberChange(event) {
        this._dispatch(event.target.value !== '' ? Number(event.target.value) : null);
    }

    handleGroupedChange(event) {
        const combined = event.target.value || '';
        const raw    = this._splitByPattern(combined, this.field?.splitPattern || 'LAST_SPACE');
        const result = this._enforceGroupPrimary(raw, combined);
        this._dispatch(result.primary);
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
