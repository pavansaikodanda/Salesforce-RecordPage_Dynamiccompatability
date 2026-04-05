import { LightningElement, api, track } from 'lwc';
import getFieldMappings from '@salesforce/apex/FieldMappingController.getFieldMappings';
import saveFieldMappings from '@salesforce/apex/FieldMappingController.saveFieldMappings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_SAVE from '@salesforce/label/c.Field_Mapping_Save_Button';
import LABEL_SEARCH from '@salesforce/label/c.Field_Mapping_Search_Placeholder';
import LABEL_LOADING from '@salesforce/label/c.Loading';
import LABEL_ERROR from '@salesforce/label/c.Error_Generic';

const TABS = ['General', 'Visibility', 'Validation', 'Permissions'];

const VISIBILITY_OPTIONS = [
    { label: 'Visible', value: 'Visible' },
    { label: 'Hidden', value: 'Hidden' },
    { label: 'Required', value: 'Required' }
];

const FIELD_SUBTYPE_OPTIONS = [
    { label: 'Standard', value: 'Standard' },
    { label: 'Address Street', value: 'Address_Street' },
    { label: 'Address City', value: 'Address_City' },
    { label: 'Address State', value: 'Address_State' },
    { label: 'Address Postal Code', value: 'Address_PostalCode' },
    { label: 'Address Country', value: 'Address_Country' }
];

export default class FieldMappingManager extends LightningElement {
    @api recordId;

    labels = {
        save: LABEL_SAVE,
        search: LABEL_SEARCH,
        loading: LABEL_LOADING,
        error: LABEL_ERROR
    };

    visibilityOptions = VISIBILITY_OPTIONS;
    fieldSubtypeOptions = FIELD_SUBTYPE_OPTIONS;
    tabs = TABS;

    @track fields = [];
    @track searchTerm = '';
    @track isLoading = true;
    @track isDirty = false;
    @track activeFieldIndex = null;
    @track activeTab = 'General';
    @track errorMessage;

    // Drag state
    _dragIndex = null;

    connectedCallback() {
        this._load();
    }

    _load() {
        this.isLoading = true;
        getFieldMappings({ objectMappingId: this.recordId })
            .then(data => {
                this.fields = data.map((f, idx) => ({
                    ...f,
                    _idx: idx,
                    displayOrder: f.displayOrder ?? idx + 1,
                    displayLabel: f.labelOverride || f.fieldLabel || f.fieldApiName,
                    stageConfigs: (f.stageConfigs || []).map((sc, si) => ({ ...sc, _uid: f.fieldApiName + '_sc_' + si })),
                    picklistPermissions: (f.picklistPermissions || []).map((pp, pi) => ({ ...pp, _uid: f.fieldApiName + '_pp_' + pi }))
                }));
                this.isLoading = false;
            })
            .catch(err => {
                this.errorMessage = err.body?.message || LABEL_ERROR;
                this.isLoading = false;
            });
    }

    get isSaveDisabled() { return !this.isDirty; }

    get filteredFields() {
        const term = this.searchTerm.toLowerCase();
        return this.fields.filter(f =>
            !term ||
            f.fieldApiName?.toLowerCase().includes(term) ||
            f.labelOverride?.toLowerCase().includes(term) ||
            f.sectionLabel?.toLowerCase().includes(term)
        );
    }

    get activeField() {
        if (this.activeFieldIndex === null) return null;
        return this.fields[this.activeFieldIndex];
    }

    get hasActiveField() {
        return this.activeField !== null;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleFieldClick(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.activeFieldIndex = idx;
        this.activeTab = 'General';
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    isTabActive(tab) {
        return this.activeTab === tab;
    }

    get activeTabs() {
        if (this.activeField?.isAlwaysRequired) return ['General'];
        return TABS;
    }

    get tabGeneral() { return this.activeTab === 'General'; }
    get tabVisibility() { return this.activeTab === 'Visibility' && !this.activeField?.isAlwaysRequired; }
    get tabValidation() { return this.activeTab === 'Validation' && !this.activeField?.isAlwaysRequired; }
    get tabPermissions() { return this.activeTab === 'Permissions' && !this.activeField?.isAlwaysRequired; }

    handleFieldPropChange(event) {
        if (this.activeFieldIndex === null) return;
        const prop = event.target.dataset.prop;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const fields = [...this.fields];
        fields[this.activeFieldIndex] = { ...fields[this.activeFieldIndex], [prop]: value };
        this.fields = fields;
        this.isDirty = true;
    }

    handleAddStageConfig() {
        if (this.activeFieldIndex === null) return;
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        field.stageConfigs = [...(field.stageConfigs || []), { stageValue: '', visibility: 'Visible', _uid: 'sc_' + Date.now() }];
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    handleStageConfigChange(event) {
        if (this.activeFieldIndex === null) return;
        const scIdx = parseInt(event.currentTarget.dataset.scIdx, 10);
        const prop = event.target.dataset.prop;
        const value = event.target.value;
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        const stageConfigs = [...field.stageConfigs];
        stageConfigs[scIdx] = { ...stageConfigs[scIdx], [prop]: value };
        field.stageConfigs = stageConfigs;
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    handleRemoveStageConfig(event) {
        if (this.activeFieldIndex === null) return;
        const scIdx = parseInt(event.currentTarget.dataset.scIdx, 10);
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        const stageConfigs = field.stageConfigs.filter((_, i) => i !== scIdx);
        field.stageConfigs = stageConfigs;
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    handleAddPicklistPermission() {
        if (this.activeFieldIndex === null) return;
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        field.picklistPermissions = [...(field.picklistPermissions || []), { picklistValue: '', customPermissionApiName: '', _uid: 'pp_' + Date.now() }];
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    handlePicklistPermissionChange(event) {
        if (this.activeFieldIndex === null) return;
        const ppIdx = parseInt(event.currentTarget.dataset.ppIdx, 10);
        const prop = event.target.dataset.prop;
        const value = event.target.value;
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        const perms = [...field.picklistPermissions];
        perms[ppIdx] = { ...perms[ppIdx], [prop]: value };
        field.picklistPermissions = perms;
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    handleRemovePicklistPermission(event) {
        if (this.activeFieldIndex === null) return;
        const ppIdx = parseInt(event.currentTarget.dataset.ppIdx, 10);
        const fields = [...this.fields];
        const field = { ...fields[this.activeFieldIndex] };
        field.picklistPermissions = field.picklistPermissions.filter((_, i) => i !== ppIdx);
        fields[this.activeFieldIndex] = field;
        this.fields = fields;
        this.isDirty = true;
    }

    // Drag to reorder
    handleDragStart(event) {
        this._dragIndex = parseInt(event.currentTarget.dataset.idx, 10);
        event.dataTransfer.effectAllowed = 'move';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    handleDrop(event) {
        event.preventDefault();
        const targetIdx = parseInt(event.currentTarget.dataset.idx, 10);
        if (this._dragIndex === null || this._dragIndex === targetIdx) return;

        const fields = [...this.fields];
        const moved = fields.splice(this._dragIndex, 1)[0];
        fields.splice(targetIdx, 0, moved);
        this.fields = fields.map((f, i) => ({ ...f, displayOrder: i + 1, _idx: i }));
        this._dragIndex = null;
        this.isDirty = true;
        if (this.activeFieldIndex !== null) {
            this.activeFieldIndex = targetIdx;
        }
    }

    handleSave() {
        this.isLoading = true;
        const payload = this.fields.map(f => ({
            fieldApiName: f.fieldApiName,
            labelOverride: f.labelOverride,
            fieldType: f.fieldType,
            fieldSubtype: f.fieldSubtype,
            addressGroup: f.addressGroup,
            isReadOnly: f.isReadOnly,
            referenceTo: f.referenceTo,
            sectionLabel: f.sectionLabel,
            displayOrder: f.displayOrder,
            defaultVisibility: f.defaultVisibility,
            isRequiredLayout: f.isRequiredLayout,
            regexPattern: f.regexPattern,
            regexErrorMessage: f.regexErrorMessage,
            isActive: f.isActive !== false
        }));

        saveFieldMappings({ objectMappingId: this.recordId, fieldMappingsJson: JSON.stringify(payload) })
            .then(() => {
                this.isLoading = false;
                this.isDirty = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Field mappings saved.',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Save Failed',
                    message: err.body?.message || LABEL_ERROR,
                    variant: 'error'
                }));
            });
    }
}
