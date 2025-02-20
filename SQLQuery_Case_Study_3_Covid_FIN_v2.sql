--Firstly, let's observe both data sets

SELECT *
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
ORDER BY 3,4

SELECT *
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Vaccinations
ORDER BY 3,4

--Now, let's select the data that we are going to use from the Covid Deaths data set for our first observation

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
ORDER BY 1,2

--Let's look at total cases vs total deaths
--We have to convert VARCHAR data to numeric, so let's do that
--Also, let's use the cast/try_cast operator to omit DIV/0 errors
--Mortality rate column shows likelihood of death if infected by Covid-19 in your country

SELECT location, date, total_cases, total_deaths, 
(TRY_CAST(total_deaths AS NUMERIC)/NULLIF(TRY_CAST(total_cases AS NUMERIC), 0)*100) as mortality_rate
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
WHERE location LIKE '%Kingdom%'
ORDER BY 1,2

--Now, let's look at total cases vs population size
--This calculation of (total cases / population) will show the proportion of the population that has contracted Covid-19

SELECT location, date, total_cases, population, 
(TRY_CAST(total_cases AS NUMERIC)/NULLIF(TRY_CAST(population AS NUMERIC), 0)*100) as pop_infection_percentage
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
WHERE location LIKE '%Kingdom%'
ORDER BY 1,2

--Let's look at countries that have the highest infection rate compared to population

SELECT location, population, MAX(TRY_CAST(total_cases AS NUMERIC)) as highest_infection_count, 
MAX((TRY_CAST(total_cases AS NUMERIC)/NULLIF(TRY_CAST(population AS NUMERIC), 0)*100)) as infection_rate_percentage
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
GROUP BY location, population
ORDER BY infection_rate_percentage DESC

--Let's look at the countries with the highest death count relative to population

SELECT location, MAX(TRY_CAST(total_deaths AS NUMERIC)) as highest_death_count
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
WHERE location NOT LIKE '%World%' 
AND location NOT LIKE '%Europe%'
AND location NOT LIKE '%America%'
AND location NOT LIKE '%Asia%'
AND location NOT LIKE '%countries%'
GROUP BY location
ORDER BY highest_death_count DESC

--Let's break things down by continent rather than country, for death count

SELECT continent, MAX(TRY_CAST(total_deaths AS NUMERIC)) as highest_death_count
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
GROUP BY continent
ORDER BY highest_death_count DESC

-- Let's look at the numbers globally
-- Now, because we are grouping by date, we need to use aggregate functions on the other columns in order to run the query
-- Let's replace total_cases with a SUM of new_cases (the result of which is essentially the total_cases number)
-- Likewise let us also do that for the deaths column, as SUM of new deaths = total deaths
-- Finally, dividing one by the other *100 gives us an aggregate global death percentage, for each date
-- Upon inspection, it also appears that new cases and new deaths are only updated once per week, leading to null values on the other 6 days. 
-- So, we can exclude those nulls using a HAVING clause after Group By

SELECT date, SUM(TRY_CAST(new_cases AS NUMERIC)) as Sum_Total_Cases, SUM(TRY_CAST(new_deaths AS NUMERIC)) as Sum_Total_Deaths,
SUM(TRY_CAST(new_deaths AS NUMERIC))/NULLIF(SUM(TRY_CAST(new_cases AS NUMERIC)), 0)*100 as Global_Death_Percentage
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
GROUP BY date
HAVING SUM(TRY_CAST(new_deaths AS NUMERIC))/NULLIF(SUM(TRY_CAST(new_cases AS NUMERIC)), 0)*100 IS NOT NULL
ORDER BY 1,2

--A small tweak gives us global data across all dates

SELECT SUM(TRY_CAST(new_cases AS NUMERIC)) as Sum_Total_Cases, SUM(TRY_CAST(new_deaths AS NUMERIC)) as Sum_Total_Deaths,
SUM(TRY_CAST(new_deaths AS NUMERIC))/NULLIF(SUM(TRY_CAST(new_cases AS NUMERIC)), 0)*100 as Global_Death_Percentage
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths
--GROUP BY date
HAVING SUM(TRY_CAST(new_deaths AS NUMERIC))/NULLIF(SUM(TRY_CAST(new_cases AS NUMERIC)), 0)*100 IS NOT NULL
ORDER BY 1,2

--Now, let's move on to joining the Vaccination data with the Death data

SELECT *
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths dth
JOIN PortfolioCaseStudy3_Covid.dbo.Covid_Vaccinations vac
	 ON dth.location = vac.location
	 AND dth.date = vac.date

--We can confirm that the data has been joined correctly
--Now, lets look at Vaccinations vs Population
--We could just query and return the total vaccination column, but instead, let's use the new vaccinations (per day) column, 
--and also create a second column - which is a rolling vaccination count, that is cumulative
--The end result of this cumulative column WILL BE the total vaccinations, per country

SELECT dth.continent, dth.location, dth.date, dth.population, vac.new_vaccinations,
SUM(TRY_CAST(vac.new_vaccinations AS NUMERIC)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS Vaccinations_Agg
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths dth
JOIN PortfolioCaseStudy3_Covid.dbo.Covid_Vaccinations vac
	 ON dth.location = vac.location
	 AND dth.date = vac.date
ORDER BY 2,3

--Common Table Expression:
--Now, let's perform some operations using our created Vaccinations_Agg column
--This cannot be done within the same query that creates said column, so let us create a CTE
--We re-use the above code and assign it to the temp table

WITH Pop_vs_vac (continent, location, date, population, new_vaccinations, Vaccinations_Agg) AS
(
SELECT dth.continent, dth.location, dth.date, dth.population, vac.new_vaccinations,
SUM(TRY_CAST(vac.new_vaccinations AS NUMERIC)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS Vaccinations_Agg
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths dth
JOIN PortfolioCaseStudy3_Covid.dbo.Covid_Vaccinations vac
	 ON dth.location = vac.location
	 AND dth.date = vac.date
)
SELECT *, (Vaccinations_Agg/population)*100 AS Pop_Vax_Agg_Percentage
FROM Pop_vs_vac

--Creating a view to store data for later visualizations

GO
CREATE VIEW Pop_Vax_View AS
SELECT dth.continent, dth.location, dth.date, dth.population, vac.new_vaccinations,
SUM(TRY_CAST(vac.new_vaccinations AS NUMERIC)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS Vaccinations_Agg
FROM PortfolioCaseStudy3_Covid.dbo.Covid_Deaths dth
JOIN PortfolioCaseStudy3_Covid.dbo.Covid_Vaccinations vac
	 ON dth.location = vac.location
	 AND dth.date = vac.date
GO
