/**
 * @description       : Used to fetch the products for lookup search based on the pricebook.
 * @author            : Cube84
 * @CreatedDate       : 07-16-2025
 * @last modified on  : 07-18-2025
 * @last modified by  : Optimized for performance and readability.
**/
import { LightningElement, track, api } from 'lwc';
import searchProducts from '@salesforce/apex/AddNewProductCustomController.searchProducts';

export default class CustomProductLookup extends LightningElement {
    // Variable declration
    @api pbId;
    @track searchKey = '';
    @track searchResults = [];
    @track selectedProduct = null;
    @track showDropdown = false;
    @track noResults = false;

    // Handling the CSS for the dropdown
    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.showDropdown ? 'slds-is-open' : ''}`;
    }

    // Handling the changes in the search input and calling the parent refiltring method when search box becomes empty
    handleSearchInput(event) {
        console.log('<<handleSearchInput>>'+event.target.value);
        this.searchKey = event.target.value;
        this.performSearch();
        if(this.searchKey == '') {
            const searchEvent = new CustomEvent('productsearch', {
                detail: {
                    type: 'text',
                    key: this.searchKey
                }
            });
            this.dispatchEvent(searchEvent);
        }
    }

    // Initiate the search logic in the parent on Enter key press
    handleKeyUp(event) {
        const isEnterKey = event.key === 'Enter';
        if (isEnterKey) {
            console.log('<<handleKeyUp>>' + isEnterKey + '<<Search Key>>' + this.searchKey);
            this.showDropdown = false;
            const searchEvent = new CustomEvent('productsearch', {
                detail: {
                    type: 'text',
                    key: this.searchKey
                }
            });
            this.dispatchEvent(searchEvent);
        }
    }

    // Sub method to perform the search from the controller based on the PriceBook Id and Search Key
    performSearch() {
        console.log('Performing search with keyword:', this.searchKey, ' and Price Book ID:', this.pbId);
        if (!this.searchKey || this.searchKey.trim() === '') {
            this.searchResults = [];
            this.noResults = false;
            this.showDropdown = false;
            return;
        }
        searchProducts({ 
            priceBookId: this.pbId,
            keyword: this.searchKey
         })
            .then((result) => {
                this.searchResults = result;
                this.noResults = result.length === 0;
                this.showDropdown = true;
            })
            .catch((error) => {
                console.error('Error in product lookup:', error);
                this.searchResults = [];
                this.noResults = true;
                this.showDropdown = true;
            });
    }

    // Method use to pass the record Id while selecting the specific product name
    handleSelect(event) {
        const productId = event.currentTarget.dataset.id;
        const productName = event.currentTarget.dataset.name;
        this.selectedProduct = {
            Id: productId,
            Name: productName
        };
        this.searchResults = [];
        this.searchKey = '';
        this.showDropdown = false;
        const selectedEvent = new CustomEvent('productsearch', {
            detail: {
                type: 'id',
                key: this.selectedProduct.Id
            }
        });
        this.dispatchEvent(selectedEvent);
    }

    // Method to handle the close icon next to the pill of the selected product to start the refiltring
    clearSelection() {
        const clearedId = this.selectedProduct?.Id;
        this.selectedProduct = null;
        this.searchKey = '';
        this.searchResults = [];
        const clearEvent = new CustomEvent('clearproduct');
        this.dispatchEvent(clearEvent);
    }
}