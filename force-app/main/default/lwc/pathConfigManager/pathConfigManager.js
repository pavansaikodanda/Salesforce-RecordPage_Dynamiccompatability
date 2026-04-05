import { LightningElement, api, track, wire } from 'lwc';
import getPathConfig from '@salesforce/apex/PathConfigController.getPathConfig';
import savePathConfig from '@salesforce/apex/PathConfigController.savePathConfig';
import getPicklistValues from '@salesforce/apex/FieldMappingController.getPicklistValues';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_SAVE from '@salesforce/label/c.Path_Config_Save_Button';
import LABEL_ADD_STAGE from '@salesforce/label/c.Path_Config_Add_Stage';
import LABEL_LOADING from '@salesforce/label/c.Loading';
import LABEL_ERROR from '@salesforce/label/c.Error_Generic';

const MAPPING_FIELDS = [
    'Custom_Object_Mapping__c.Object_API_Name__c',
    'Custom_Object_Mapping__c.Stage_Picklist_Field__c',
    'Custom_Object_Mapping__c.Enforce_Path_Order__c',
    'Custom_Object_Mapping__c.Stage_Order_Source__c'
];

export default class PathConfigManager extends LightningElement {
    @api recordId;

    labels = {
        save: LABEL_SAVE,
        addStage: LABEL_ADD_STAGE,
        loading: LABEL_LOADING,
        error: LABEL_ERROR
    };

    @track stages = [];
    @track transitions = [];
    @track enforceOrder = false;
    @track stageOrderSource = 'Custom Order';
    @track stageValueOptions = [];
    @track isLoading = true;
    @track isDirty = false;
    @track errorMessage;

    _objectApiName;
    _stagePicklistField;
    _dragIndex = null;

    @wire(getRecord, { recordId: '$recordId', fields: MAPPING_FIELDS })
    wiredMapping({ data, error }) {
        if (data) {
            this._objectApiName = data.fields.Object_API_Name__c?.value;
            this._stagePicklistField = data.fields.Stage_Picklist_Field__c?.value;
            this.enforceOrder = data.fields.Enforce_Path_Order__c?.value || false;
            this.stageOrderSource = data.fields.Stage_Order_Source__c?.value || 'Custom Order';

            if (this._objectApiName && this._stagePicklistField) {
                this._loadPicklistValues();
            }
            this._loadPathConfig();
        } else if (error) {
            this.errorMessage = error.body?.message || LABEL_ERROR;
            this.isLoading = false;
        }
    }

    _loadPicklistValues() {
        getPicklistValues({ objectApiName: this._objectApiName, fieldApiName: this._stagePicklistField })
            .then(values => {
                this.stageValueOptions = values.map(v => ({ label: v.label, value: v.value }));
            })
            .catch(() => {});
    }

    _loadPathConfig() {
        this.isLoading = true;
        getPathConfig({ objectMappingId: this.recordId })
            .then(config => {
                this.stages = (config.stages || []).map((s, i) => ({ ...s, _idx: i }));
                this.transitions = (config.transitions || []).map((t, i) => ({ ...t, _idx: i }));
                this.isLoading = false;
            })
            .catch(err => {
                this.errorMessage = err.body?.message || LABEL_ERROR;
                this.isLoading = false;
            });
    }

    get isSaveDisabled() { return !this.isDirty; }

    get stageOrderSourceOptions() {
        return [
            { label: 'Custom Order', value: 'Custom Order' },
            { label: 'Picklist Order', value: 'Picklist Order' }
        ];
    }

    get allStageOptions() {
        if (this.stageValueOptions.length) return this.stageValueOptions;
        return this.stages.map(s => ({ label: s.stageValue, value: s.stageValue }));
    }

    handleConfigChange(event) {
        const prop = event.target.dataset.prop;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        if (prop === 'enforceOrder') this.enforceOrder = value;
        else if (prop === 'stageOrderSource') this.stageOrderSource = value;
        this.isDirty = true;
    }

    handleAddStage() {
        const stages = [...this.stages, {
            stageValue: '',
            stageLabel: '',
            stageOrder: this.stages.length + 1,
            guidanceText: '',
            _idx: this.stages.length
        }];
        this.stages = stages;
        this.isDirty = true;
    }

    handleStageChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const prop = event.target.dataset.prop;
        const value = event.target.value;
        const stages = [...this.stages];
        stages[idx] = { ...stages[idx], [prop]: value };
        this.stages = stages;
        this.isDirty = true;
    }

    handleRemoveStage(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const removedValue = this.stages[idx].stageValue;
        this.stages = this.stages
            .filter((_, i) => i !== idx)
            .map((s, i) => ({ ...s, stageOrder: i + 1, _idx: i }));
        this.transitions = this.transitions.filter(
            t => t.fromStage !== removedValue && t.toStage !== removedValue
        );
        this.isDirty = true;
    }

    handleAddTransition() {
        this.transitions = [...this.transitions, {
            fromStage: '',
            toStage: '',
            isAllowed: true,
            _idx: this.transitions.length
        }];
        this.isDirty = true;
    }

    handleTransitionChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const prop = event.target.dataset.prop;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const transitions = [...this.transitions];
        transitions[idx] = { ...transitions[idx], [prop]: value };
        this.transitions = transitions;
        this.isDirty = true;
    }

    handleRemoveTransition(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.transitions = this.transitions
            .filter((_, i) => i !== idx)
            .map((t, i) => ({ ...t, _idx: i }));
        this.isDirty = true;
    }

    // Drag to reorder stages
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

        const stages = [...this.stages];
        const moved = stages.splice(this._dragIndex, 1)[0];
        stages.splice(targetIdx, 0, moved);
        this.stages = stages.map((s, i) => ({ ...s, stageOrder: i + 1, _idx: i }));
        this._dragIndex = null;
        this.isDirty = true;
    }

    handleSave() {
        this.isLoading = true;
        const payload = {
            enforceOrder: this.enforceOrder,
            stageOrderSource: this.stageOrderSource,
            stages: this.stages.map(s => ({
                stageValue: s.stageValue,
                stageLabel: s.stageLabel,
                stageOrder: s.stageOrder,
                guidanceText: s.guidanceText
            })),
            transitions: this.transitions.map(t => ({
                fromStage: t.fromStage,
                toStage: t.toStage,
                isAllowed: t.isAllowed
            }))
        };

        savePathConfig({ objectMappingId: this.recordId, pathConfigJson: JSON.stringify(payload) })
            .then(() => {
                this.isLoading = false;
                this.isDirty = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Path configuration saved.',
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
