
/**
 * Transforms specimen data into labels that can be printed
 */
function transformData(data) {
    const labelOutput = document.getElementById('label-output');
    if (!labelOutput || !labelOutput.previousElementSibling) return;

    // Clear out old labels
    labelOutput.innerHTML = '';

    const labels = data;

    const transformedData = labels.map((label) => {

        // const gpsLatitude = label.latitude ? `${label.latitude}°N` : '';
        // const gpsLongitude = label.longitude ? `${Math.abs(label.longitude)}°W` : '';

        const temperature = `${label.temperatureC} (${label.temperatureF})`;

        return `<div class="single-label">
            <div class="label-locality">
                <span>
                    ${label.location}
                </span>
                <span>
                    ${label.latitude}
                    ${label.longitude}
                </span>
                <span>
                    ${label.dateTimeOriginal}
                </span>
                <span>
                    ${temperature}, ${label.address?.elevation || ''}
                </span>
                <span>
                    ${label.collector}
                </span>
            </div>`
            + ( label.notes? `
              <div class="label-notes">
                  <span>
                      ${label.notes}
                  </span>
              </div>` : '' )
            + ( label.qrCode? `
              <div class="label-taxonomy">
                  <span>
                      ${label.qrCode}
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
