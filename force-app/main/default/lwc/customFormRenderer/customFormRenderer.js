import { LightningElement, api, wire, track } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import STAGE_CHANGE_CHANNEL from '@salesforce/messageChannel/CustomFormStageChange__c';
import getFormConfig from '@salesforce/apex/FormConfigController.getFormConfig';
import saveRecord from '@salesforce/apex/FormSaveController.saveRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_SAVE from '@salesforce/label/c.Form_Save_Button';
import LABEL_CANCEL from '@salesforce/label/c.Form_Cancel_Button';
import LABEL_SAVE_SUCCESS from '@salesforce/label/c.Form_Save_Success';
import LABEL_SAVE_ERROR from '@salesforce/label/c.Form_Save_Error';
import LABEL_REQUIRED from '@salesforce/label/c.Form_Validation_Required';
import LABEL_REGEX from '@salesforce/label/c.Form_Validation_Regex';
import LABEL_LOADING from '@salesforce/label/c.Loading';
import LABEL_ERROR from '@salesforce/label/c.Error_Generic';

export default class CustomFormRenderer extends LightningElement {
    @api developerName;
    @api recordId;

    @wire(MessageContext) messageContext;

    labels = {
        save: LABEL_SAVE,
        cancel: LABEL_CANCEL,
        loading: LABEL_LOADING,
        error: LABEL_ERROR
    };

    @track formConfig;
    @track fieldValues = {};
    @track fieldErrors = {};
    @track isLoading = true;
    @track errorMessage;
    @track currentStage;

    _subscription;

    connectedCallback() {
        this._loadConfig();
        this._subscription = subscribe(this.messageContext, STAGE_CHANGE_CHANNEL, (msg) => {
            if (!this.recordId || msg.recordId === this.recordId) {
                this.currentStage = msg.stageValue;
            }
        });
    }

    disconnectedCallback() {
        if (this._subscription) unsubscribe(this._subscription);
    }

    _loadConfig() {
        this.isLoading = true;
        getFormConfig({ developerName: this.developerName, recordId: this.recordId })
            .then(config => {
                this.formConfig = config;
                this.currentStage = config.currentStageValue;
                // Pre-populate field values from current record
                this.fieldValues = config.currentRecordData ? { ...config.currentRecordData } : {};
                this.isLoading = false;
            })
            .catch(err => {
                this.errorMessage = err.body?.message || LABEL_ERROR;
                this.isLoading = false;
            });
    }

    get objectApiName() {
        return this.formConfig?.objectApiName;
    }

    get userPermissions() {
        return this.formConfig?.userPermissions || [];
    }

    get visibleSections() {
        if (!this.formConfig?.fields) return [];

        const fields = this.formConfig.fields.filter(f => this._isFieldVisible(f));
        const sectionMap = new Map();

        for (const field of fields) {
            const sec = field.sectionLabel || 'General';
            if (!sectionMap.has(sec)) sectionMap.set(sec, []);
            sectionMap.get(sec).push(this._buildFieldRow(field));
        }

        return Array.from(sectionMap.entries()).map(([label, fields]) => ({ label, fields }));
    }

    get addressGroups() {
        if (!this.formConfig?.fields) return [];

        const groups = new Map();
        for (const field of this.formConfig.fields) {
            if (field.fieldSubtype && field.fieldSubtype !== 'Standard' && field.addressGroup) {
                if (!groups.has(field.addressGroup)) groups.set(field.addressGroup, []);
                groups.get(field.addressGroup).push(field);
            }
        }

        return Array.from(groups.entries()).map(([groupName, fields]) => ({ groupName, fields }));
    }

    _isFieldVisible(field) {
        const vis = this._resolveVisibility(field);
        return vis === 'Visible' || vis === 'Required';
    }

    _isFieldRequired(field) {
        if (field.isRequiredLayout) return true;
        return this._resolveVisibility(field) === 'Required';
    }

    _resolveVisibility(field) {
        if (!this.currentStage || !field.stageConfigs?.length) {
            return field.defaultVisibility || 'Visible';
        }
        const stageConfig = field.stageConfigs.find(sc => sc.stageValue === this.currentStage);
        return stageConfig ? stageConfig.visibility : field.defaultVisibility || 'Visible';
    }

    _buildFieldRow(field) {
        return {
            ...field,
            value: this.fieldValues[field.fieldApiName] ?? field.defaultValue ?? null,
            required: this._isFieldRequired(field),
            disabled: field.isReadOnly,
            error: this.fieldErrors[field.fieldApiName] || null
        };
    }

    handleValueChange(event) {
        const { fieldApiName, value } = event.detail;
        this.fieldValues = { ...this.fieldValues, [fieldApiName]: value };
        if (this.fieldErrors[fieldApiName]) {
            const errors = { ...this.fieldErrors };
            delete errors[fieldApiName];
            this.fieldErrors = errors;
        }
    }

    handleSave() {
        if (!this._validate()) return;

        this.isLoading = true;
        const payload = {};
        for (const field of (this.formConfig?.fields || [])) {
            if (field.isReadOnly) continue;
            if (this.fieldValues[field.fieldApiName] !== undefined) {
                payload[field.fieldApiName] = this.fieldValues[field.fieldApiName];
            }
        }

        saveRecord({
            objectApiName: this.objectApiName,
            recordId: this.recordId || null,
            fieldDataJson: JSON.stringify(payload),
            developerName: this.developerName
        })
            .then(result => {
                this.isLoading = false;
                if (result.isSuccess) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: LABEL_SAVE_SUCCESS,
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CustomEvent('save', { detail: { recordId: result.recordId } }));
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: LABEL_SAVE_ERROR,
                        message: result.errorMessage,
                        variant: 'error'
                    }));
                }
            })
            .catch(err => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_SAVE_ERROR,
                    message: err.body?.message || LABEL_ERROR,
                    variant: 'error'
                }));
            });
    }

    handleCancel() {
        this.fieldValues = this.formConfig?.currentRecordData ? { ...this.formConfig.currentRecordData } : {};
        this.fieldErrors = {};
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    _validate() {
        const errors = {};
        let valid = true;

        for (const field of (this.formConfig?.fields || [])) {
            if (!this._isFieldVisible(field)) continue;
            if (this._isFieldRequired(field)) {
                const val = this.fieldValues[field.fieldApiName];
                if (val === null || val === undefined || val === '') {
                    errors[field.fieldApiName] = LABEL_REQUIRED;
                    valid = false;
                    continue;
                }
            }
            if (field.regexPattern) {
                const val = this.fieldValues[field.fieldApiName];
                if (val) {
                    const regex = new RegExp(field.regexPattern);
                    if (!regex.test(String(val))) {
                        errors[field.fieldApiName] = field.regexErrorMessage || LABEL_REGEX;
                        valid = false;
                    }
                }
            }
        }

        this.fieldErrors = errors;
        return valid;
    }
}
