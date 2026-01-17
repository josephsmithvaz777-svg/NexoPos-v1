<template>
    <div id="camera-scan-popup" class="ns-box shadow-lg flex flex-col overflow-hidden" :style="popupStyle">
        <div class="p-2 border-b ns-box-header flex justify-between items-center">
            <h3 class="text-fontcolor">{{ __( 'Scan Product' ) }}</h3>
            <div>
                <ns-close-button @click="closePopup()"></ns-close-button>
            </div>
        </div>
        <div class="flex-auto overflow-hidden flex flex-col items-center justify-center bg-black relative">
            <div id="reader" class="w-full h-full"></div>
            <div v-if="error" class="absolute bottom-5 bg-red-500 text-white p-2 rounded z-10">
                {{ error }}
            </div>
            <div v-if="scannedCode && !productFound" class="absolute inset-0 bg-black bg-opacity-90 flex items-center justify-center z-20 p-4">
                <div class="bg-white rounded-lg p-6 max-w-md w-full">
                    <h3 class="text-lg font-bold mb-4">{{ __( 'Product Not Found' ) }}</h3>
                    <p class="mb-4">{{ __( 'Barcode:' ) }} <strong>{{ scannedCode }}</strong></p>
                    <p class="mb-6 text-gray-600">{{ __( 'This product does not exist. Would you like to create it?' ) }}</p>
                    <div class="flex gap-3">
                        <button @click="createNewProduct()" class="flex-1 ns-button info">
                            <i class="las la-plus mr-2"></i>{{ __( 'Create Product' ) }}
                        </button>
                        <button @click="resetScan()" class="flex-1 ns-button default">
                            {{ __( 'Scan Again' ) }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
        <div class="p-2 border-t ns-box-footer flex justify-between items-center gap-2">
            <input 
                ref="fileInput" 
                type="file" 
                accept="image/*" 
                @change="handleFileUpload" 
                class="hidden"
            />
            <button @click="$refs.fileInput.click()" class="ns-button default flex items-center gap-2">
                <i class="las la-image"></i>
                <span class="hidden sm:inline">{{ __( 'Upload Image' ) }}</span>
            </button>
            <button @click="switchCamera()" class="ns-button default" v-if="cameras.length > 1">
                <i class="las la-sync-alt mr-2"></i>{{ __( 'Switch Camera' ) }}
            </button>
        </div>
    </div>
</template>

<script>
import { Html5Qrcode, Html5QrcodeSupportedFormats } from "html5-qrcode";
import popupCloser from "~/libraries/popup-closer";
import popupResolver from '~/libraries/popup-resolver';
import { nsHttpClient, nsSnackBar } from '~/bootstrap';
import { __ } from '~/libraries/lang';

export default {
    name: 'ns-pos-camera-scan',
    props: [ 'popup' ],
    data() {
        return {
            html5QrCode: null,
            cameras: [],
            currentCameraIndex: 0,
            isScanning: false,
            error: null,
            scannedCode: null,
            productFound: true,
            lastScannedCode: null,
            lastScanTime: 0,
        }
    },
    computed: {
        popupStyle() {
            // Force full width on mobile with inline styles
            const isMobile = window.innerWidth < 768;
            if (isMobile) {
                return {
                    width: '100vw',
                    height: '95vh',
                    maxWidth: '100vw'
                };
            }
            return {
                width: '75vw',
                height: '70vh',
                maxWidth: '900px'
            };
        }
    },
    mounted() {
        this.initializeScanner();
    },
    beforeUnmount() {
        this.stopScanner();
    },
    methods: {
        __,
        popupCloser,
        popupResolver,

        closePopup() {
            this.stopScanner().then(() => {
                this.popup.close();
            });
        },

        async initializeScanner() {
            try {
                this.cameras = await Html5Qrcode.getCameras();
                if (this.cameras && this.cameras.length) {
                    // Try to find rear camera (environment facing)
                    const rearCameraIndex = this.cameras.findIndex(camera => 
                        camera.label && (
                            camera.label.toLowerCase().includes('back') ||
                            camera.label.toLowerCase().includes('rear') ||
                            camera.label.toLowerCase().includes('environment')
                        )
                    );
                    
                    // Use rear camera if found, otherwise use first camera
                    this.currentCameraIndex = rearCameraIndex !== -1 ? rearCameraIndex : 0;
                    
                    this.html5QrCode = new Html5Qrcode("reader");
                    this.startScanning(this.cameras[this.currentCameraIndex].id);
                } else {
                    this.error = __( 'No cameras found.' );
                }
            } catch (err) {
                this.error = __( 'Error accessing camera.' );
                console.error(err);
            }
        },

        startScanning(cameraId) {
            // Calculate optimal qrbox size based on viewport
            const viewportWidth = Math.min(window.innerWidth, 600);
            const qrboxSize = Math.floor(viewportWidth * 0.85);
            
            this.html5QrCode.start(
                cameraId, 
                {
                    fps: 20,
                    qrbox: { 
                        width: qrboxSize, 
                        height: Math.floor(qrboxSize * 0.4) // Wider box for barcodes
                    },
                    aspectRatio: 1.777778,
                    formatsToSupport: [
                        Html5QrcodeSupportedFormats.EAN_13,
                        Html5QrcodeSupportedFormats.EAN_8,
                        Html5QrcodeSupportedFormats.CODE_128,
                        Html5QrcodeSupportedFormats.CODE_39,
                        Html5QrcodeSupportedFormats.UPC_A,
                        Html5QrcodeSupportedFormats.UPC_E,
                        Html5QrcodeSupportedFormats.QR_CODE
                    ]
                },
                (decodedText, decodedResult) => {
                    this.onScanSuccess(decodedText, decodedResult);
                },
                (errorMessage) => {
                    // parse error, ignore it.
                }
            )
            .then(() => {
                this.isScanning = true;
            })
            .catch((err) => {
                this.error = __( 'Unable to start scanning.' );
                console.error(err);
            });
        },

        stopScanner() {
            if (this.html5QrCode && this.isScanning) {
                return this.html5QrCode.stop().then(() => {
                    this.isScanning = false;
                }).catch(err => {
                    console.error("Failed to stop scanner", err);
                });
            }
            return Promise.resolve();
        },

        async switchCamera() {
            if (this.cameras.length > 1) {
                await this.stopScanner();
                this.currentCameraIndex = (this.currentCameraIndex + 1) % this.cameras.length;
                this.startScanning(this.cameras[this.currentCameraIndex].id);
            }
        },

        async handleFileUpload(event) {
            const file = event.target.files[0];
            if (!file) return;

            try {
                await this.stopScanner();
                
                const html5QrCode = new Html5Qrcode("reader");
                const result = await html5QrCode.scanFile(file, true);
                
                this.onScanSuccess(result, null);
                
                // Restart camera after file scan
                setTimeout(() => {
                    this.initializeScanner();
                }, 1000);
            } catch (err) {
                nsSnackBar.error(__( 'Could not read barcode from image.' ));
                console.error(err);
                // Restart camera
                this.initializeScanner();
            }
        },

        onScanSuccess(decodedText, decodedResult) {
            // Debounce: prevent scanning the same code multiple times
            const now = Date.now();
            const timeSinceLastScan = now - this.lastScanTime;
            
            // If same code scanned within 2 seconds, ignore it
            if (this.lastScannedCode === decodedText && timeSinceLastScan < 2000) {
                return;
            }
            
            // Update last scan info
            this.lastScannedCode = decodedText;
            this.lastScanTime = now;
            
            // Play a success sound
            const audio = new Audio('/audio/ding.mp3');
            audio.play().catch(e => {});

            // Search for the product
            this.submitSearch(decodedText);
        },

        submitSearch( value ) {
            if ( value.length > 0 ) {
                const url = nsHooks.applyFilters( 'ns-pos-submit-search-url', `/api/products/search/using-barcode/${ value }`, value );

                nsHttpClient.get( url )
                    .subscribe({
                        next: result => {
                            POS.addToCart( result.product );
                            nsSnackBar.success( __( 'Product added to cart.' ) );
                            this.closePopup();
                        },
                        error: ( error ) => {
                            // Product not found - show creation dialog
                            this.scannedCode = value;
                            this.productFound = false;
                        }
                    })
            }
        },

        createNewProduct() {
            // Close scanner and redirect to product creation page with barcode pre-filled
            this.closePopup();
            
            // Get the product creation URL from settings
            const createUrl = POS.settings.getValue().urls.products_url || '/dashboard/products/create';
            
            // Open in new tab with barcode as query parameter
            window.open(`${createUrl}?barcode=${this.scannedCode}`, '_blank');
            
            nsSnackBar.info(__( 'Opening product creation page...' ));
        },

        resetScan() {
            this.scannedCode = null;
            this.productFound = true;
            // Scanner will continue running
        }
    }
}
</script>

<style scoped>
#reader {
    width: 100%;
    height: 100%;
}

#camera-scan-popup {
    position: relative;
}

/* Ensure popup is centered */
@media (max-width: 768px) {
    #camera-scan-popup {
        margin: 0 !important;
        border-radius: 0 !important;
    }
}
</style>