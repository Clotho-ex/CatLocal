# App Review Notes

## Contact

- Contact: Yusufcan Var
- Email: info@catlocal.app
- Phone: enter privately in App Store Connect; do not commit it

## Review notes

CatLocal is a local-first iPhone field journal for real cat encounters. No
account or sign-in is required.

The primary flow is:

1. Open the Camera tab.
2. Photograph a cat or choose a private photo from the photo library.
3. CatLocal uses Apple Vision on-device to detect the cat and create a
   foreground cutout.
4. Choose a card design and optionally add a name, note, and manually typed
   Memory Place.
5. Save the card to the private local collection.

Camera and photo-library access are used only after the reviewer chooses the
corresponding action. CatLocal does not request location access. Memory Place
and Catlas labels are typed manually and are not coordinates.

Cat detection, foreground separation, and cutout generation run on-device.
CatLocal has no account system, analytics, advertising, remote AI, photo
upload, cloud database, or remote storage. Saved originals are re-encoded
without source EXIF or GPS metadata, and the app stores its records and image
variants locally.

Privacy Policy: https://catlocal.app/privacy/

Support: https://catlocal.app/support/

No special credentials, hardware, or review configuration are required. A
photo containing a clearly visible cat is needed to exercise the complete
import flow in Simulator.
