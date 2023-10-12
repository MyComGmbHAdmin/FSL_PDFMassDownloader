# README - FSL Dispatcher Console Mass Action: Download

## Overview

This repository contains a Visualforce page (`DownloadPDFController.page`) and its associated Apex controller (`DownloadPDFController.cls`). The Visualforce page is designed to be used in the context of Salesforce's Field Service Lightning (FSL) Dispatcher Console. Specifically, it serves as part of a mass action called "Download," which allows you to download PDF files for selected service appointments directly from the Dispatcher Console.

## Visualforce Page (`DownloadPDFController.page`)

The Visualforce page serves as the user interface for the "Download" mass action within the FSL Dispatcher Console. It leverages the capabilities of the associated Apex controller to facilitate the selection of service appointments, PDF template choice, and the subsequent generation and download of PDF files. Here's an overview of the page:

- The page is associated with the `DownloadPDFController` Apex controller, providing the necessary functionality.
- It displays a table with a list of selected service appointments, enabling users to choose multiple appointments.
- Users can select a PDF template from a dropdown list.
- The "Download PDFs" button triggers the PDF generation and download process.

## Apex Controller (`DownloadPDFController.cls`)

The `DownloadPDFController` Apex controller is the heart of the mass action, handling the business logic, Salesforce data interactions, PDF generation, and user interactions. It provides the following key functionalities:

- `selectedAppointments`: A list of service appointments selected by users.
- `templateOptions`: A list of available PDF templates for selection.
- `paramId`, `paramStart`, and `paramEnd` are properties used to capture parameters from the URL.

### Controller Initialization

- The controller's constructor initializes by capturing URL parameters and retrieving selected service appointments.
- It also populates the `templateOptions` by fetching available PDF templates.

### PDF Generation

- The controller provides methods to create PDF titles (`createTitle`) and generate PDF files using selected templates (`createPDFUsingTemplate`).
- The `getPDF` method retrieves the PDF content. During testing, it returns a dummy value.

## Dependencies

- The PDF generation is facilitated by a Visualforce page named `pdfwrapper`, which is likely defined elsewhere in your Salesforce setup.
- The JavaScript library `JSZip` is used to create and download a zip file containing generated PDFs.

## FSL Dispatcher Console Mass Action Setup

1. Configure the "Download" mass action in the FSL Dispatcher Console to call the `DownloadPDFController.page` with the necessary parameters, which include selected service appointments and date ranges if applicable.
2. Ensure that the Visualforce page and Apex controller are correctly associated within your Salesforce environment.
3. Make sure you have the required PDF templates and the `pdfwrapper` Visualforce page in your Salesforce setup.
4. Include the necessary JavaScript library, `JSZip`, in your Salesforce instance.

## Usage

1. Access the FSL Dispatcher Console within Salesforce.
2. Select the service appointments you want to include in the mass action.
3. Initiate the "Download" mass action.
4. The Visualforce page associated with the mass action will be triggered, allowing you to choose a PDF template and generate PDFs for the selected appointments.
5. Click the "Download PDFs" button to initiate PDF generation and download.

## Disclaimer

This repository provides a basic setup for generating PDFs from selected service appointments in the context of the FSL Dispatcher Console. It may require further customization and integration with your Salesforce environment to work seamlessly. Ensure that you handle error cases and testing in your specific Salesforce setup.

---

*Credits: Fabian Bertea*
