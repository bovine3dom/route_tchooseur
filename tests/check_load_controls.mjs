import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const {layers, maps} = JSON.parse(readFileSync(0, 'utf8'));
const metrics = {max_axle_load_t: 'axle', max_mass_per_m_t: 'per_m', load_speed_kmh: 'speed'};
const compile = expression => new Function(`"use strict"; return (${expression})`)();
let checked = 0;
for (const {id, format, metadata} of maps) {
    const fields = Object.entries(metadata.controls).map(([id, definition]) => ({
        id, ...definition,
        visible: definition.showIf ? compile(definition.showIf) : () => true,
        convert: definition.encode ? compile(definition.encode) : value => value,
    }));
    const defaults = Object.fromEntries(fields.map(field => [field.id, field.default]));
    function check(inputs, layer) {
        Object.freeze(inputs);
        const criterion = metrics[layer.predicate];
        const expected = ['shown', inputs.shown === 'speed' ? 'criterion_load' : 'criterion_speed', criterion, 'format'];
        const visible = fields.filter(field => field.visible(inputs));
        assert.deepEqual(visible.map(field => field.id), expected);
        assert.deepEqual(visible.map(field => field.label), ['Value shown', 'Criterion', 'Criterion value', 'Map format']);
        for (const field of fields.filter(field => field.type === 'select')) {
            assert(field.options.some(option => option.value === inputs[field.id]), `Invalid ${field.id} value`);
        }
        const encoded = Object.fromEntries(fields.map(field => [`controls.${field.id}`, field.convert(inputs[field.id], inputs)]));
        const url = metadata.onchange.url.replace(/\{(controls\.\w+)\}/g, (_, key) => encoded[key]);
        assert.equal(encoded['controls.layer'], layer.id);
        assert.equal(url, `data/track-loads/${inputs.format}/${layer.id}.${inputs.format === 'h3' ? 'csv' : 'geojson'}`);
        assert.equal(metadata.onchange.format, 'auto');
        assert(!metadata.onclick && !metadata.onmove);
        checked++;
    }
    check(defaults, layers.find(layer => layer.id === id));
    for (const layer of layers) {
        const criterion = metrics[layer.predicate];
        for (const loadCriterion of ['axle', 'per_m']) {
            // Change hidden inputs too: they must not affect the selected file.
            const inputs = Object.fromEntries(fields.map(field => [field.id,
                field.options?.find(option => option.value !== field.default)?.value ?? field.default]));
            Object.assign(inputs, {shown: metrics[layer.value], format,
                criterion_load: criterion === 'speed' ? loadCriterion : criterion,
                [criterion]: String(layer.threshold)});
            for (const representation of ['h3', 'geojson']) check({...inputs, format: representation}, layer);
        }
    }
}
console.log(`Checked ${checked} control states: three query controls, map format, and valid static file URLs`);
