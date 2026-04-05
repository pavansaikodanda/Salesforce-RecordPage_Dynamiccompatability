import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import getObjects from '@salesforce/apex/ObjectMappingController.getObjects';
import getPageLayouts from '@salesforce/apex/ObjectMappingController.getPageLayouts';
import syncFields from '@salesforce/apex/FieldSyncController.syncFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_SYNC from '@salesforce/label/c.Sync_Button';
import LABEL_SYNC_SUCCESS from '@salesforce/label/c.Sync_Success';
import LABEL_SAVE from '@salesforce/label/c.Form_Save_Button';
import LABEL_LOADING from '@salesforce/label/c.Loading';
import LABEL_SELECT_OBJECT from '@salesforce/label/c.Object_Mapping_Select_Object';
import LABEL_SELECT_LAYOUT from '@salesforce/label/c.Object_Mapping_Select_Layout';
import LABEL_ERROR from '@salesforce/label/c.Error_Generic';

const FIELDS = [
    'Custom_Object_Mapping__c.Name',
    'Custom_Object_Mapping__c.Developer_Name__c',
    'Custom_Object_Mapping__c.Object_API_Name__c',
    'Custom_Object_Mapping__c.Page_Layout_ID__c',
    'Custom_Object_Mapping__c.Page_Layout_Name__c',
    'Custom_Object_Mapping__c.Stage_Picklist_Field__c',
    'Custom_Object_Mapping__c.Enforce_Path_Order__c',
    'Custom_Object_Mapping__c.Stage_Order_Source__c',
    'Custom_Object_Mapping__c.Is_Active__c'
];

export default class CustomObjectMappingForm extends LightningElement {
    @api recordId;

    labels = {
        sync: LABEL_SYNC,
        save: LABEL_SAVE,
        loading: LABEL_LOADING,
        selectObject: LABEL_SELECT_OBJECT,
        selectLayout: LABEL_SELECT_LAYOUT,
        error: LABEL_ERROR
    };

    @track formData = {
        Name: '',
        Developer_Name__c: '',
        Object_API_Name__c: '',
        Page_Layout_ID__c: '',
        Page_Layout_Name__c: '',
        Stage_Picklist_Field__c: '',
        Enforce_Path_Order__c: false,
        Stage_Order_Source__c: 'Custom Order',
        Is_Active__c: true
    };

    @track objectOptions = [];
    @track layoutOptions = [];
    @track isLoading = true;
    @track isSyncing = false;
    @track errorMessage;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            const f = data.fields;
            this.formData = {
                Name: f.Name?.value || '',
                Developer_Name__c: f.Developer_Name__c?.value || '',
                Object_API_Name__c: f.Object_API_Name__c?.value || '',
                Page_Layout_ID__c: f.Page_Layout_ID__c?.value || '',
                Page_Layout_Name__c: f.Page_Layout_Name__c?.value || '',
                Stage_Picklist_Field__c: f.Stage_Picklist_Field__c?.value || '',
                Enforce_Path_Order__c: f.Enforce_Path_Order__c?.value || false,
                Stage_Order_Source__c: f.Stage_Order_Source__c?.value || 'Custom Order',
                Is_Active__c: f.Is_Active__c?.value !== false
            };
            if (this.formData.Object_API_Name__c) {
                this._loadLayouts(this.formData.Object_API_Name__c);
            }
        } else if (error) {
            this.errorMessage = error.body?.message || LABEL_ERROR;
        }
    }

    @wire(getObjects)
    wiredObjects({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.objectOptions = data.map(o => ({ label: o.label, value: o.apiName }));
        } else if (error) {
            this.errorMessage = error.body?.message || LABEL_ERROR;
        }
    }

    _loadLayouts(objectApiName) {
        getPageLayouts({ objectApiName })
            .then(layouts => {
                this.layoutOptions = layouts.map(l => ({ label: l.name, value: l.id }));
            })
            .catch(err => {
                this.errorMessage = err.body?.message || LABEL_ERROR;
            });
    }

    get stageOrderSourceOptions() {
        return [
            { label: 'Custom Order', value: 'Custom Order' },
            { label: 'Picklist Order', value: 'Picklist Order' }
        ];
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.formData = { ...this.formData, [field]: value };

        if (field === 'Object_API_Name__c' && value) {
            this.layoutOptions = [];
            this.formData = { ...this.formData, Page_Layout_ID__c: '', Page_Layout_Name__c: '' };
            this._loadLayouts(value);
        }

        if (field === 'Page_Layout_ID__c') {
            const selected = this.layoutOptions.find(l => l.value === value);
            if (selected) {
                this.formData = { ...this.formData, Page_Layout_Name__c: selected.label };
            }
        }
    }

    handleSave() {
        this.isLoading = true;
        const fields = {
            Id: this.recordId,
            Name: this.formData.Name,
            Developer_Name__c: this.formData.Developer_Name__c,
            Object_API_Name__c: this.formData.Object_API_Name__c,
            Page_Layout_ID__c: this.formData.Page_Layout_ID__c,
            Page_Layout_Name__c: this.formData.Page_Layout_Name__c,
            Stage_Picklist_Field__c: this.formData.Stage_Picklist_Field__c,
            Enforce_Path_Order__c: this.formData.Enforce_Path_Order__c,
            Stage_Order_Source__c: this.formData.Stage_Order_Source__c,
            Is_Active__c: this.formData.Is_Active__c
        };

        updateRecord({ fields })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Object mapping saved.',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isLoading = false;
                this.errorMessage = err.body?.message || LABEL_ERROR;
            });
    }

    handleSync() {
        this.isSyncing = true;
        syncFields({ objectMappingId: this.recordId })
            .then(result => {
                this.isSyncing = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sync Complete',
                    message: LABEL_SYNC_SUCCESS
                        .replace('{0}', result.added)
                        .replace('{1}', result.removed)
                        .replace('{2}', result.unchanged),
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isSyncing = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sync Failed',
                    message: err.body?.message || LABEL_ERROR,
                    variant: 'error'
                }));
            });
    }
}
