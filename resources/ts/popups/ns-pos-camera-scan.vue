<template>
    <div id="camera-scan-popup" class="ns-box shadow-lg w-full h-95vh md:h-[70vh] md:w-3/4 lg:w-2/3 flex flex-col overflow-hidden">
        <div class="p-2 border-b ns-box-header flex justify-between items-center">
            <h3 class="text-fontcolor">{{ __( 'Scan Product' ) }}</h3>
            <div>
                <ns-close-button @click="closePopup()"></ns-close-button>
            </div>
        </div>
        <div class="flex-auto overflow-hidden flex flex-col items-center justify-center bg-black relative">
            <div id="reader" class="w-full h-full"></div>
            <div v-if="error" class="absolute bottom-5 bg-red-500 text-white p-2 rounded">
                {{ error }}
            </div>
        </div>
        <div class="p-2 border-t ns-box-footer flex justify-center">
            <button @click="switchCamera()" class="ns-button default" v-if="cameras.length > 1">
                {{ __( 'Switch Camera' ) }}
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
            const viewportWidth = Math.min(window.innerWidth, 500);
            const qrboxSize = Math.floor(viewportWidth * 0.8);
            
            this.html5QrCode.start(
                cameraId, 
                {
                    fps: 20, // Increased FPS for smoother scanning
                    qrbox: { 
                        width: qrboxSize, 
                        height: Math.floor(qrboxSize * 0.5) // Wider box for barcodes
                    },
                    aspectRatio: 1.777778, // 16:9 aspect ratio
                    // Prioritize barcode formats
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

        onScanSuccess(decodedText, decodedResult) {
            // Play a beep sound if possible
            const audio = new Audio('/audio/beep.mp3'); // Assuming a beep sound exists or browser default
            audio.play().catch(e => {});

            // Stop scanning temporarily or close? 
            // Usually in POS you want to scan one item and maybe scan another.
            // But let's close it for now or debounce it.
            
            // Let's try to find the product
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
                            this.closePopup(); // Close after successful scan? Or keep open?
                            // For now, let's close it to emulate "scanning one item".
                        },
                        error: ( error ) => {
                            nsSnackBar.error( error.message || __( 'Product not found.' ) );
                        }
                    })
            }
        }
    }
}
</script>

<style scoped>
#reader {
    width: 100%;
    height: 100%;
}
</style>