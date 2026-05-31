
/**
 * Transforms specimen data into labels that can be printed
 */
function transformData(data) {
    const labelOutput = document.getElementById('label-output');
    if (!labelOutput || !labelOutput.previousElementSibling) return;

    const safeText = (value) => (value === undefined || value === null ? '' : String(value));

    // Clear out old labels
    labelOutput.innerHTML = '';

    const labels = data;

    const transformedData = labels.map((label) => {
        const location = safeText(label.location);
        const latitude = safeText(label.latitude);
        const longitude = safeText(label.longitude);
        const dateTimeOriginal = safeText(label.dateTimeOriginal);
        const temperature = safeText(label.temperature);
        const elevation = safeText(label.address?.elevation);
        const collector = safeText(label.collector);
        const notes = safeText(label.notes);
        const qrCode = safeText(label.qrCode);
        const latLong = [latitude, longitude].filter(Boolean).join(', ');
        const tempAndElevation = [temperature, elevation].filter(Boolean).join(', ');

        return `<div class="single-label">
            <div class="label-locality">
                <span>
                    ${location}
                </span>
                <span>
                    ${latLong}
                </span>
                <span>
                    ${dateTimeOriginal}
                </span>
                <span>
                    ${tempAndElevation}
                </span>
                <span>
                    ${collector}
                </span>
            </div>`
            + ( notes ? `
              <div class="label-notes">
                  <span>
                      ${notes}
                  </span>
              </div>` : '' )
            + ( qrCode ? `
              <div class="label-taxonomy">
                  <span class="label-id">
                      ${qrCode}
                  </span>
              </div>` : '' )
        + `</div>`;
    });

    labelOutput.innerHTML = transformedData.join('');

    // Tell the user how many labels were generated
    labelOutput.previousElementSibling.innerHTML = `${transformedData.length} labels generated for the above data`;
}

async function loadPhotos() {
    const content = document.getElementById('label-output');
    content.innerHTML = '<div class="loading">Loading photos...</div>';
    
    try {
        const response = await fetch('/specimens.json');
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        
        const specimens = await response.json();
        
        if (!Array.isArray(specimens) || specimens.length === 0) {
            content.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">📭</div>
                    <h2>No specimens found</h2>
                    <p>Select photos from the app to view them here.</p>
                </div>
            `;
            return;
        }
        
        transformData(specimens);
        
    } catch (error) {
        console.error('Error loading specimens:', error);
        content.innerHTML = `
            <div class="error">
                <strong>Error:</strong> Failed to load specimen data. ${error.message}
            </div>
        `;
    }
}


loadPhotos();
