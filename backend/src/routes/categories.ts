import { Router } from 'express';
import { prisma } from '../lib/prisma';

export const categoriesRouter = Router();

// Public list of active categories, used by brand registration and session forms.
categoriesRouter.get('/', async (_req, res, next) => {
  try {
    const categories = await prisma.category.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: 'asc' },
      select: { id: true, name: true },
    });
    res.json({ categories });
  } catch (error) {
    next(error);
  }
});
