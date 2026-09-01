import { Router } from 'express';
import * as shippingController from '../controllers/shippingController';

export const shippingRouter = Router();

// 1. Get 250kg Toy Manifest
shippingRouter.get('/manifest', shippingController.getToyManifest);

// 2. Compare Rates across ShipEngine, Shippo, EasyPost, Sendcloud
shippingRouter.post('/compare', shippingController.compareRates);

// 3. Provider Specific Endpoints
shippingRouter.post('/shipengine', shippingController.getShipEngineRates);
shippingRouter.post('/shippo', shippingController.getShippoRates);
shippingRouter.post('/easypost', shippingController.getEasyPostRates);
shippingRouter.post('/sendcloud', shippingController.getSendcloudRates);
