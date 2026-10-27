/*
 * Copyright (c) 2014-2026 Bjoern Kimminich & the OWASP Juice Shop contributors.
 * SPDX-License-Identifier: MIT
 */

import path from 'node:path'
import { type Request, type Response, type NextFunction } from 'express'
import { ProductModel } from '../models/product'
import { BasketModel } from '../models/basket'
import * as challengeUtils from '../lib/challengeUtils'

import * as utils from '../lib/utils'
import * as security from '../lib/insecurity'
import { challenges } from '../data/datacache'

export function retrieveBasket () {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id
      const basket = await BasketModel.findOne({ where: { id }, include: [{ model: ProductModel, paranoid: false, as: 'Products' }] })
      /* jshint eqeqeq:false */
      challengeUtils.solveIf(challenges.basketAccessChallenge, () => {
        const user = security.authenticatedUsers.from(req)
        const isValidId = id && id !== 'undefined' && id !== 'null' && id !== 'NaN'
        return user && isValidId && user.bid && user?.bid != parseInt(id, 10) // eslint-disable-line eqeqeq
      })
      if (((basket?.Products) != null) && basket.Products.length > 0) {
        for (let i = 0; i < basket.Products.length; i++) {
          basket.Products[i].name = req.__(basket.Products[i].name)
        }
      }

      res.json(utils.queryResultToJson(basket))
    } catch (error) {
      next(error)
    }
  }
}

export function exportBasketSnapshot () {
  return (req: Request, res: Response, next?: NextFunction) => {
    const tenant = String(req.query.tenant ?? 'default')
    const file = String(req.query.file ?? 'basket.json')

    if (
      tenant.includes('/') ||
      tenant.includes('\\') ||
      tenant.includes('..') ||
      tenant.includes('\0') ||
      tenant === '.' ||
      tenant.trim() === '' ||
      file.includes('/') ||
      file.includes('\\') ||
      file.includes('..') ||
      file.includes('\0') ||
      file === '.' ||
      file.trim() === ''
    ) {
      res.status(403)
      if (typeof next === 'function') {
        next(new Error('File names cannot contain forward slashes!'))
      } else {
        res.send('File names cannot contain forward slashes!')
      }
      return
    }

    const baseDir = path.resolve('/var/tmp/exports')
    const tenantDir = path.resolve(baseDir, tenant)
    const target = security.resolveExportTarget(tenant, file)
    const resolvedTarget = path.resolve(target)

    if (
      !tenantDir.startsWith(baseDir + path.sep) ||
      !resolvedTarget.startsWith(tenantDir + path.sep)
    ) {
      res.status(403)
      if (typeof next === 'function') {
        next(new Error('File names cannot contain forward slashes!'))
      } else {
        res.send('File names cannot contain forward slashes!')
      }
      return
    }

    res.sendFile(resolvedTarget)
  }
}
